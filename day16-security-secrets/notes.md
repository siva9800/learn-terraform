# Day 16 - Security and Secrets

> **Goal:** learn how to authenticate Terraform without ever writing a key in a `.tf` file, understand why secrets end up in state in plain text (and what to do about it), read secrets safely from a secrets manager, and harden the resources you build.

> **Interactive demo:** [Secrets in State animation](https://siva9800.github.io/devops-animations/terraform/secrets-in-state.html) - watch a "sensitive" password get masked in the CLI while still sitting in the state file in plain text.

---

## What problem does this solve?

On Day 1 you launched a server. Somewhere along the way Terraform had to prove to AWS that it was allowed to do that - it needed credentials. And many real resources need secrets: a database wants a master password, an app wants an API token.

The dangerous, tempting shortcut is to type those secrets straight into your code:

```hcl
provider "aws" {
  access_key = "AKIAIOSFODNN7EXAMPLE"        # NEVER do this
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}
```

The moment that file touches Git, anyone who can read the repo - or the repo's entire history, forever - owns your AWS account. Bots scan public GitHub for exactly this and drain accounts within minutes.

This lesson is about doing it right: proving your identity to AWS without storing keys, keeping real secrets out of your code, and accepting the uncomfortable truth that Terraform's state file records secrets in plain text - so you must protect the state itself.

---

## Learning Objectives

By the end of Day 16 you will be able to:
- Authenticate the AWS provider safely - shared credentials, env vars, IAM roles, OIDC - and rank the methods by safety.
- Apply least privilege to the identity Terraform runs as.
- Explain why `sensitive = true` masks CLI output but does **not** encrypt state.
- Encrypt state at rest and lock down who can read the state bucket.
- Read secrets from AWS Secrets Manager and SSM Parameter Store via `data` sources instead of hardcoding them.
- Generate secrets with `random_password` and store them safely.
- Keep `*.tfstate`, `*.tfvars`, and `.terraform/` out of Git.
- Harden resources (encryption, tight security groups) and let scanners catch mistakes.

---

## Real-world analogy: your PIN, a hotel keycard, and a diary in a safe

Three images that carry this whole lesson.

- **Hardcoding a key in `.tf` = writing your PIN on your debit card.** The one thing that must stay secret is now attached to the thing everyone can see. If the card (repo) is lost, the account is gone.
- **IAM roles = a hotel keycard.** You never carry the master key. Reception hands you a card that only opens *your* room and expires at checkout. On an EC2 instance or in ECS, the machine is handed a short-lived credential automatically - there is no long-lived key to steal because none exists.
- **State-with-secrets = a diary that writes down your passwords.** Terraform's state is a helpful diary of everything it built - including passwords it saw. Marking a value `sensitive` just means the diary is written in faint ink so it does not shout the password across the room. The words are still there. So you lock the diary in a safe (encrypt state, restrict access) - and better still, avoid writing real passwords into it at all.

Keep the diary image in mind. It is the single most misunderstood thing about Terraform security.

---

## Provider authentication done right

Terraform needs to prove who it is to AWS. There are several ways, and they are not equally safe. The rule: **credentials should live outside your code, and ideally not exist as long-lived keys at all.**

### Local development

For work on your own laptop, let the AWS CLI hold the credentials. Terraform picks them up automatically - your `.tf` files stay clean.

```bash
aws configure
# stores keys in ~/.aws/credentials, region in ~/.aws/config
```

```hcl
# Your code only ever names the region. No keys anywhere.
provider "aws" {
  region = "us-east-1"
}
```

Or use environment variables (handy for one-off sessions and CI):

```bash
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_REGION="us-east-1"
```

Terraform reads `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_REGION` on its own - you do not reference them in HCL.

### On AWS compute: IAM roles (no keys at all)

When Terraform runs *on* AWS - an EC2 instance, ECS task, or CodeBuild job - attach an **IAM role** (via an instance profile). AWS injects temporary, auto-rotating credentials that the SDK finds automatically. There is literally no key to leak.

```hcl
# The EC2 box that runs Terraform gets a role - not a stored key.
resource "aws_iam_role" "terraform_runner" {
  name = "terraform-runner"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "terraform_runner" {
  name = "terraform-runner"
  role = aws_iam_role.terraform_runner.name
}
```

### In CI: OIDC (recap from Day 14)

In GitHub Actions, do not store an AWS access key as a repo secret. Use **OIDC**: GitHub presents a short-lived, signed token, and AWS trades it for temporary credentials by assuming a role. No long-lived secret is ever stored.

```yaml
# GitHub Actions - no AWS keys stored anywhere
permissions:
  id-token: write   # allows GitHub to mint the OIDC token
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/gha-terraform
      aws-region: us-east-1
```

### Ranked by safety

| Method | Where | Long-lived key stored? | Safety |
|---|---|---|---|
| **IAM role / instance profile** | Terraform runs on EC2/ECS/CodeBuild | No - temporary auto-rotating creds | Best |
| **OIDC federation** | CI (GitHub Actions, GitLab) | No - short-lived token exchanged for a role | Best |
| **Named CLI profile / SSO** | Local dev | On disk, but never in the repo | Good |
| **Environment variables** | Local, CI | In the shell/session only | OK |
| **Shared credentials file** (`~/.aws/credentials`) | Local dev | Long-lived, on disk | OK-ish |
| **Hardcoded keys in `.tf`** | anywhere | Yes - in code and Git history | Never |

> **One line for interviews:** the safest credential is the one that does not exist as a stored key - IAM roles and OIDC hand out short-lived credentials, so there is nothing to leak.

---

## Least privilege for the Terraform identity

Whatever identity Terraform assumes, give it only the permissions it actually needs. A common mistake is to attach `AdministratorAccess` "so it just works." That means a leaked credential - or a bad `apply` - can touch everything.

- Scope the policy to the services and resources this project manages (EC2, RDS, S3 for one app - not the whole account).
- Prefer separate roles per environment (a `dev` role cannot touch `prod`).
- Deny the ability to read other teams' state buckets.

Least privilege limits the blast radius. If the keycard only opens one room, losing it is annoying, not catastrophic.

---

## The BIG secrets problem: state stores everything in plain text

This is the part everyone gets wrong, so read it twice.

**Terraform's state file records the full attributes of everything it manages - including secrets - as plain text JSON.** A database password, a generated key, any variable marked `sensitive = true` - all of it lands in `terraform.tfstate` in readable form.

```mermaid
flowchart TB
    V["variable db_password<br/>sensitive = true"] --> P["terraform plan / apply<br/>value MASKED in CLI output"]
    P --> S["terraform.tfstate<br/>value stored in PLAIN TEXT"]
    S --> R["Anyone who can read state<br/>reads the secret"]
    style V fill:#e3f2fd,stroke:#1565c0
    style P fill:#fff3e0,stroke:#e65100
    style S fill:#ffebee,stroke:#c62828
    style R fill:#ffebee,stroke:#c62828
```

`sensitive = true` only changes one thing: it stops Terraform from *printing* the value in `plan`/`apply` output and in the console. It does **not** encrypt state, and it does **not** keep the value out of state. The diary still records the password; you just wrote it in faint ink.

So the defense is threefold:

1. **Encrypt state at rest.** Store state in an S3 backend with encryption on, ideally with your own KMS key.
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "my-tf-state"
       key            = "app/terraform.tfstate"
       region         = "us-east-1"
       encrypt        = true                              # server-side encryption
       kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/abc-123"
       use_lockfile   = true                              # native state locking (Terraform 1.10+)
     }
   }
   ```
2. **Lock down who can read the state bucket.** Treat it like the secret it contains. Block public access, restrict the bucket policy to the Terraform role only, enable versioning and access logging.
3. **Prefer not putting real secrets into Terraform at all.** The best-protected secret is the one Terraform never has to know. That is what the next section is about.

---

## Better patterns for secrets

### Pattern 1: reference secrets at apply time via data sources

Instead of typing a password into your code, store it once in **Secrets Manager** or **SSM Parameter Store**, then have Terraform *read* it when it applies. The secret never appears in your `.tf` files or your Git history.

```hcl
# Read an existing secret from Secrets Manager (created outside Terraform).
data "aws_secretsmanager_secret" "db" {
  name = "prod/app/db-password"
}

data "aws_secretsmanager_secret_version" "db" {
  secret_id = data.aws_secretsmanager_secret.db.id
}

# Or read an encrypted SSM SecureString parameter, decrypting on read.
data "aws_ssm_parameter" "db_password" {
  name            = "/prod/app/db-password"
  with_decryption = true
}
```

Now feed that value into a resource without ever writing the literal secret:

```hcl
resource "aws_db_instance" "app" {
  identifier     = "app-db"
  engine         = "postgres"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  username       = "appadmin"

  # Secret comes from Secrets Manager at apply time - not from your code.
  password = data.aws_secretsmanager_secret_version.db.secret_string

  storage_encrypted   = true
  skip_final_snapshot  = true
}
```

> **Honest caveat:** the value you read still gets written into state (the diary sees it). This pattern keeps the secret out of your *code and Git*, which is a big win - but it is **not** a substitute for encrypting state. Do both.

### Pattern 2: generate a secret and store it safely

Sometimes you want Terraform to invent a password. Use `random_password`, then push it straight into Secrets Manager so your app can fetch it later.

```hcl
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+"
}

resource "aws_secretsmanager_secret" "db" {
  name = "prod/app/db-password"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = random_password.db.result
}
```

> Both `random_password.db.result` and the secret version land in state in plain text. Same rule: encrypt state, restrict access.

### Pattern 3: inject secrets via environment variables in CI

Terraform reads any environment variable named `TF_VAR_<name>` as the value for `variable "<name>"`. So in CI you can pass a secret without ever committing a `tfvars` file.

```hcl
variable "db_password" {
  type      = string
  sensitive = true   # masks CLI output only - see the diary caveat
}
```

```bash
# In CI, from the pipeline's secret store - not committed to Git.
export TF_VAR_db_password="$CI_DB_PASSWORD"
terraform apply -auto-approve
```

This beats a committed `secrets.tfvars`, because nothing sensitive lives in the repo.

---

## Never commit these

Some files must never reach Git. Recap the `.gitignore` from Day 1 and keep it strict:

```
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl   # optional to commit; never commit provider caches
*.tfvars              # if they hold secrets
crash.log
```

| Do | Do not |
|---|---|
| Read secrets from Secrets Manager / SSM at apply time | Type passwords or keys into `.tf` files |
| Pass secrets via `TF_VAR_*` env vars in CI | Commit `secrets.tfvars` to the repo |
| Encrypt state and restrict the state bucket | Assume `sensitive = true` protects state |
| Use IAM roles / OIDC for auth | Store long-lived AWS keys in code or repo secrets |
| Add a strict `.gitignore` before your first commit | Commit `*.tfstate` or `.terraform/` |

To stop accidents automatically, add a guard that scans commits for secrets:

- **git-secrets** - hooks that reject a commit if it matches AWS key patterns.
- **pre-commit** - a framework to run `detect-secrets`, `tfsec`, and formatters on every commit.

```bash
# Example: block AWS keys before they ever get committed
git secrets --install
git secrets --register-aws
```

---

## Secure resource configuration (defense in depth)

Keeping secrets safe is only half the job. The resources you build must be hardened too. These are exactly the checks the scanners from Day 13 (tfsec, trivy, checkov) flag.

```mermaid
flowchart LR
    A["Auth: IAM roles / OIDC<br/>least privilege"] --> B["State: encrypted<br/>bucket locked down"]
    B --> C["Secrets: read from<br/>Secrets Manager / SSM"]
    C --> D["Resources: encrypt +<br/>tight security groups"]
    D --> E["Scanners: tfsec / trivy /<br/>checkov catch mistakes"]
    style A fill:#e3f2fd,stroke:#1565c0
    style B fill:#fff3e0,stroke:#e65100
    style C fill:#f3e5f5,stroke:#6a1b9a
    style D fill:#e8f5e9,stroke:#2e7d32
    style E fill:#ffebee,stroke:#c62828
```

The essentials:

- **Encrypt data at rest** - `storage_encrypted = true` on RDS, `encrypted = true` on EBS, server-side encryption + `block_public_access` on S3.
- **No `0.0.0.0/0` on SSH (port 22) or database ports.** Restrict ingress to known CIDRs or other security groups.
- **Restrict security groups** to the minimum ports and sources needed.
- **Enable versioning and access logging** on important buckets so you can recover and audit.

```hcl
# A locked-down security group: no open-to-the-world SSH.
resource "aws_security_group" "db" {
  name        = "app-db-sg"
  description = "Allow Postgres only from the app tier"

  ingress {
    description     = "Postgres from app servers only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]   # not 0.0.0.0/0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## Sensitive outputs

If an output value is derived from a secret, mark the output `sensitive = true` so Terraform does not print it. And remember: if you feed a `sensitive` value into another expression, Terraform tracks that "sensitivity" through it, so downstream values stay masked too.

```hcl
output "db_endpoint" {
  value = aws_db_instance.app.endpoint
}

output "db_password" {
  value     = data.aws_secretsmanager_secret_version.db.secret_string
  sensitive = true   # hides it from CLI output; still in state
}
```

Same rule as always: this masks the terminal, not the state file.

---

## A concise secure example

Pulling it together: an RDS instance whose password comes from Secrets Manager (never hardcoded), a locked-down security group, encryption on, and a fresh AMI lookup for the app server - no hardcoded AMI.

```hcl
provider "aws" {
  region = "us-east-1"
}

# State encrypted at rest and locked down (see backend block earlier).

# Fresh AMI - never hardcode an AMI ID (Day 1).
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Secret read at apply time - not written in code.
data "aws_secretsmanager_secret" "db" {
  name = "prod/app/db-password"
}

data "aws_secretsmanager_secret_version" "db" {
  secret_id = data.aws_secretsmanager_secret.db.id
}

resource "aws_security_group" "app" {
  name        = "app-sg"
  description = "App tier"
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Postgres from app tier only"
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]   # locked down
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app.id]
  tags = { Name = "app-server" }
}

resource "aws_db_instance" "app" {
  identifier             = "app-db"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "appadmin"
  password               = data.aws_secretsmanager_secret_version.db.secret_string
  vpc_security_group_ids = [aws_security_group.db.id]
  storage_encrypted      = true                    # encrypt at rest
  skip_final_snapshot    = true
}

output "db_endpoint" {
  value = aws_db_instance.app.endpoint
}
```

Every secret in this file is read, never written. Every resource is encrypted and scoped. This is the pattern a scanner passes and an interviewer wants to hear.

---

## Common Mistakes

1. **Believing `sensitive = true` encrypts state.** It only masks CLI output. The value sits in `terraform.tfstate` in plain text. Encrypt state and restrict access.
2. **Hardcoding AWS keys in `.tf`.** Use `aws configure`, env vars, IAM roles, or OIDC. Never keys in code.
3. **Committing `*.tfstate` or `secrets.tfvars`.** State can contain secrets; tfvars often do. `.gitignore` them and add git-secrets/pre-commit.
4. **Giving Terraform `AdministratorAccess`.** Scope to least privilege so a leak or bad apply cannot touch everything.
5. **Leaving `0.0.0.0/0` on SSH or DB ports.** Restrict to known CIDRs or a source security group.
6. **Forgetting to encrypt RDS/EBS/S3.** Set `storage_encrypted`/`encrypted`/SSE. Let tfsec/trivy/checkov catch what you miss.

---

## Hands-On Lab: read a secret instead of hardcoding it

```bash
# 1. Create a secret in AWS (outside Terraform, so it never touches your code)
aws secretsmanager create-secret \
  --name prod/app/db-password \
  --secret-string "$(openssl rand -base64 24)"

# 2. In main.tf, add the two data blocks that read that secret
#    (aws_secretsmanager_secret + aws_secretsmanager_secret_version)
#    and an aws_db_instance whose password references the version.

# 3. Configure the S3 backend with encrypt = true (state encrypted at rest)

terraform fmt
terraform validate
terraform init
terraform plan     # notice the password is MASKED in the output

terraform apply

# 4. Now prove the diary caveat to yourself: the value is masked above,
#    but if you pull remote state it is in there as plain text.
terraform state pull | grep -i password   # you will SEE the secret

# 5. Clean up
terraform destroy
aws secretsmanager delete-secret --secret-id prod/app/db-password --force-delete-without-recovery
```

**Success check:** the password never appears in your `.tf` files, it is masked in `plan`/`apply`, and step 4 shows it plainly in state - which is exactly why you encrypted the state bucket.

---

## Quick Self-Check

1. Does `sensitive = true` encrypt the value in the state file? What does it actually do?
2. Rank these by safety for authenticating Terraform: hardcoded keys in `.tf`, IAM instance role, shared credentials file.
3. How do you give an RDS instance a password without writing that password in your `.tf` files?
4. Name three things that must never be committed to Git in a Terraform project.
5. Why is `0.0.0.0/0` on port 22 a problem, and what should you do instead?

<details>
<summary>Answers</summary>

1. No. It only masks the value in CLI output (`plan`, `apply`, console). The value is still stored in `terraform.tfstate` in plain text, so you must encrypt state and restrict who can read it.
2. Safest: IAM instance role (temporary, auto-rotating, nothing to leak). Then shared credentials file (long-lived but on disk, not in the repo). Worst: hardcoded keys in `.tf` (in code and Git history forever).
3. Store the password in Secrets Manager (or SSM Parameter Store), then read it with a `data "aws_secretsmanager_secret_version"` (or `data "aws_ssm_parameter"` with `with_decryption = true`) and pass that into the `password` argument. It stays out of your code - but still lands in state, so encrypt state too.
4. Any of: `*.tfstate` / `*.tfstate.*`, `.terraform/`, and `*.tfvars` that hold secrets (plus any hardcoded credentials).
5. It opens SSH to the entire internet, so bots can attempt to break in. Restrict ingress to known CIDR ranges (like your office/VPN) or to a specific source security group.
</details>

---

## Summary

- The safest credential is one that is not a stored key - use IAM roles on AWS compute and OIDC in CI; for local dev use `aws configure` or env vars, never keys in code.
- Give the Terraform identity least privilege, not `AdministratorAccess`.
- `sensitive = true` masks CLI output only - it does **not** encrypt state. Secrets sit in `terraform.tfstate` in plain text, so encrypt state (S3 `encrypt = true` + KMS) and lock down the bucket.
- Prefer reading secrets from Secrets Manager / SSM via `data` sources over hardcoding; generate with `random_password` and store in Secrets Manager; inject via `TF_VAR_*` in CI. All of these still touch state - so encrypt it.
- Harden resources (encrypt RDS/EBS/S3, tight security groups, no `0.0.0.0/0` on SSH) and let tfsec/trivy/checkov catch mistakes.

**Next up ->** [Day 17 - Capstone Project](../day17-capstone/notes.md)
