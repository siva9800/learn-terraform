# Terraform - Day 4: Variables & Outputs

> **Goal:** Stop hard-coding values inside your Terraform files. Learn to make your infrastructure flexible, reusable, and safe using **input variables**, **local values**, and **outputs** - so the same code can build a tiny dev sandbox or a giant production setup just by changing a few settings.

So far we have been typing values *directly* into our `.tf` files - region names, instance sizes, counts. That works for one example, but it falls apart the moment you want to:

- Reuse the same code for **dev**, **staging**, and **prod**.
- Avoid copy-pasting (and forgetting to change a value somewhere).
- Hide secrets like passwords from your screen and logs.

Variables and outputs solve exactly this problem. They turn a rigid script into a reusable **template**.

---

## Learning Objectives

By the end of this day, you will be able to:

- Explain the difference between **input variables**, **local values**, and **output values**.
- Declare variables with **types**, **defaults**, and **descriptions**.
- Protect inputs with **`validation {}`** blocks.
- Hide secrets using **`sensitive = true`**.
- Pass values using **`.tfvars`** files, the **CLI**, and **environment variables**.
- Recite the **variable precedence order** (which value wins when several are set).
- Keep code tidy with `terraform fmt` and catch errors early with `terraform validate`.

---

## Real-World Analogy

Imagine you are filling out an **online form** to order a pizza.

| Terraform concept | Pizza ordering analogy |
|---|---|
| **Input variable** | A **blank field on the form** you fill in - "Size?", "Toppings?". You decide the value. |
| **default value** | The field is **pre-filled** with "Medium". If you do nothing, you get Medium. |
| **`validation {}`** | The form **rejects** "Extra Extra Giant" because that size doesn't exist. |
| **`sensitive = true`** | Your **credit card number** shows as `****` so people behind you can't read it. |
| **Local value** | A **scratchpad / shortcut** - "let's call the full address `delivery_target` so I don't retype it 5 times". |
| **`.tfvars` file** | A **saved profile** - "Home order" vs "Office order" - pick one and all fields fill in. |
| **Output value** | The **order confirmation receipt** printed at the end - "Your order number is 4821, ETA 30 min". |

You write the *form* (the template) **once**. Everyone who uses it just fills in the blanks.

---

## Input Variables - the "blanks you fill in"

You **declare** a variable (define the blank field), then **use** it elsewhere with `var.<name>`.

```hcl
# variables.tf  - declaring the blanks
variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_count" {
  description = "How many servers to create"
  type        = number
  default     = 1
}

variable "enable_monitoring" {
  description = "Turn detailed monitoring on or off"
  type        = bool
  default     = false
}
```

```hcl
# main.tf  - using the blanks
provider "aws" {
  region = var.aws_region          # <-- value comes from the variable
}

# Look up a fresh, region-correct AMI instead of hardcoding one
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "web" {
  count         = var.instance_count
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  monitoring    = var.enable_monitoring
}
```

> **Never hardcode an AMI like `ami-0c55b159cbfafe1f0`.** AMI IDs are region-specific and get retired by Amazon over time, so a literal ID breaks when you change region or as it ages. Use a `data "aws_ami"` lookup (as above) or pass the AMI in as a variable.

> **Three parts of a variable:** `description` (a human note so future-you remembers what it's for), `type` (what kind of value is allowed), and `default` (the value used if nobody supplies one). Only `type`/`default` are optional - always add `description` anyway, it's free documentation.

---

## Variable Types

Terraform checks the **type** so you can't accidentally pass text where a number belongs.

| Type | Example value | Use for |
|---|---|---|
| `string` | `"us-east-1"` | Names, regions, text |
| `number` | `3` | Counts, ports, sizes |
| `bool` | `true` / `false` | On/off switches |
| `list(string)` | `["a", "b", "c"]` | An **ordered** collection |
| `set(string)` | `["a", "b"]` | A collection with **no duplicates** |
| `map(string)` | `{ env = "dev" }` | Key -> value lookups, tags |
| `object({...})` | `{ name = "x", port = 80 }` | A **structured record** with named fields |
| `tuple([...])` | `["a", 1, true]` | A fixed list of mixed types |

```hcl
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "common_tags" {
  type = map(string)
  default = {
    Environment = "dev"
    Team        = "platform"
  }
}

variable "server" {
  type = object({
    name = string
    size = string
    port = number
  })
  default = {
    name = "web-01"
    size = "t2.micro"
    port = 80
  }
}
```

---

## Validation - reject bad input early

A `validation {}` block lets you set **rules**. If the rule fails, Terraform stops *before* touching any cloud resources - much cheaper than failing halfway through.

```hcl
variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t2.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type must be one of: t2.micro, t3.micro, t3.small."
  }
}

variable "environment" {
  type = string

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "environment must be dev, staging, or prod."
  }
}
```

- `condition` must evaluate to `true` for the value to be accepted.
- `error_message` is what the user sees when they break the rule.
- `contains(list, item)` and `regex(...)` are handy built-in functions for this.

> Think of validation as the **bouncer** at the door - wrong value, no entry.

---

## Sensitive Variables - hide secrets

Mark anything secret (passwords, tokens, keys) with `sensitive = true`. Terraform will then print `(sensitive value)` instead of the real thing in plan/apply output and console.

```hcl
variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true            # <-- hidden in CLI output
}

output "db_connection" {
  value     = "postgres://admin:${var.db_password}@db.example.com"
  sensitive = true              # outputs must also be marked sensitive
}
```

> **`sensitive = true` hides it from the screen, NOT from the state file.** The real value is still stored in `terraform.tfstate` in plain text. Protecting state is a Day 5 topic - never commit state to git, and use a secure remote backend.

---

## Local Values - your scratchpad

A **local** is a named expression you compute **once** and reuse. Unlike a variable, you can't override it from outside - it's an internal shortcut. Great for stitching values together and avoiding repetition.

```hcl
locals {
  project     = "shopfront"
  environment = var.environment

  # Build a naming prefix once, reuse everywhere
  name_prefix = "${local.project}-${local.environment}"

  # Merge standard tags onto everything
  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id   # never hardcode an AMI ID
  instance_type = var.instance_type
  tags          = merge(local.common_tags, { Name = "${local.name_prefix}-web" })
}
```

> **Variable vs Local:** A *variable* is an input from the outside world (you fill it in). A *local* is computed inside the code (you can't set it from the CLI). Rule of thumb: if the user should choose it -> variable; if it's derived/combined -> local.

---

## Output Values - the receipt

Outputs print useful results after `apply` and let other configs/modules read your values.

```hcl
output "instance_public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.web.public_ip
}

output "instance_id" {
  description = "ID of the web server"
  value       = aws_instance.web.id
}
```

```bash
terraform output                  # show all outputs
terraform output instance_public_ip   # show one output
terraform output -json            # machine-readable (great for scripts)
```

---

## Passing Values: `.tfvars` files

A `.tfvars` file is a **saved settings profile**. Keep one per environment:

```hcl
# dev.tfvars
aws_region     = "us-east-1"
instance_count = 1
environment    = "dev"
instance_type  = "t2.micro"
```

```hcl
# prod.tfvars
aws_region     = "us-west-2"
instance_count = 5
environment    = "prod"
instance_type  = "t3.small"
```

```bash
terraform apply -var-file="dev.tfvars"     # build dev
terraform apply -var-file="prod.tfvars"    # build prod - same code!
```

**Auto-loaded files** (no flag needed): Terraform automatically reads `terraform.tfvars` and any file ending in `.auto.tfvars`.

---

## Variable Precedence - who wins?

When the *same* variable is set in more than one place, Terraform follows a strict order. **Highest priority wins.**

```mermaid
flowchart TD
    A["1 Command line -var / -var-file<br/>(highest priority - wins)"] --> B["2 *.auto.tfvars files<br/>(alphabetical order)"]
    B --> C["3 terraform.tfvars / terraform.tfvars.json"]
    C --> D["4 Environment variables<br/>TF_VAR_name"]
    D --> E["5 default value in variable {} block<br/>(lowest priority - fallback)"]
    E --> F[" No value anywhere - Terraform prompts you interactively"]

    style A fill:#c8e6c9,stroke:#2e7d32
    style E fill:#ffe0b2,stroke:#e65100
    style F fill:#ffcdd2,stroke:#c62828
```

**Order from STRONGEST to WEAKEST:**

1. **`-var` and `-var-file` on the command line** - beats everything.
2. **`*.auto.tfvars`** files (loaded automatically, alphabetical).
3. **`terraform.tfvars`** (the default auto-loaded file).
4. **Environment variables** named `TF_VAR_<name>`, e.g. `TF_VAR_aws_region`.
5. **`default`** value inside the `variable {}` block (the last resort).

If none of these provide a value and there's no default, Terraform **interactively prompts** you on the terminal.

```bash
# Environment variable example (note the TF_VAR_ prefix)
export TF_VAR_aws_region="eu-west-1"      # Linux/Mac
$env:TF_VAR_aws_region = "eu-west-1"      # PowerShell (Windows)

# This CLI -var OVERRIDES the env var above:
terraform apply -var="aws_region=ap-south-1"
```

---

## Formatting & Validating

Two commands you should run constantly:

```bash
terraform fmt          # auto-format files to canonical style (fixes indentation/spacing)
terraform fmt -recursive   # format all subfolders too
terraform validate     # check syntax & internal consistency (no cloud calls)
```

- `fmt` keeps every file looking the same - no more arguments about spaces.
- `validate` catches typos and type mismatches **before** you run a plan. It does **not** check whether your cloud credentials or resources are valid - it only checks the config itself.

---

## Common Mistakes

1. **Confusing `var.` and `local.`** - input variables are `var.name`; locals are `local.name`. Mixing them up gives "Reference to undeclared..." errors.
2. **Putting secrets in `.tfvars` and committing them to git.** Add `*.tfvars` to `.gitignore` (except example files) and use `sensitive = true`. Remember: `sensitive` still leaves the value in state.
3. **Forgetting the `TF_VAR_` prefix** on environment variables. `aws_region=x` does nothing; it must be `TF_VAR_aws_region=x`.
4. **Expecting `terraform validate` to catch cloud errors.** It only validates the configuration, not whether your AMI or region actually exists.
5. **Hard-coding values "just for now".** That "temporary" hard-coded region has a way of reaching production. Make it a variable from the start.

---

## Hands-On Lab

**Goal:** Build a reusable EC2 template that works for both dev and prod.

1. Create `variables.tf` with: `aws_region` (string, default `us-east-1`), `instance_count` (number, default 1), `environment` (string, validated to dev/staging/prod), and `db_password` (string, `sensitive = true`).
2. Create `main.tf` that uses these variables and a `locals` block to build a `name_prefix` like `myapp-dev`.
3. Add `outputs.tf` printing the instance public IP and the `name_prefix`.
4. Create `dev.tfvars` and `prod.tfvars` with different counts and regions.
5. Run:
   ```bash
   terraform fmt
   terraform validate
   terraform plan -var-file="dev.tfvars"
   terraform plan -var-file="prod.tfvars"
   ```
6. **Experiment with precedence:** set `TF_VAR_aws_region`, then override it with `-var="aws_region=..."` on the CLI. Watch which one the plan uses.
7. Try giving `environment = "production"` - confirm the validation block rejects it.

---

## Quick Self-Check

1. What is the difference between an **input variable** and a **local value**?
2. Put these in order of precedence (strongest first): `default`, `-var` CLI flag, `TF_VAR_` env var, `terraform.tfvars`.
3. What does `sensitive = true` hide - and what does it **not** protect?
4. Which two files are loaded **automatically** without a `-var-file` flag?
5. What does `terraform validate` check, and what does it NOT check?

<details>
<summary>Answers</summary>

1. An **input variable** is filled in from outside (CLI, tfvars, env, or default) - the user chooses it. A **local value** is computed inside the code from other values and cannot be set from outside.
2. `-var` CLI flag > `terraform.tfvars` > `TF_VAR_` env var > `default` (strongest to weakest).
3. It hides the value from CLI plan/apply/console output. It does **not** protect the value in `terraform.tfstate`, where it is still stored in plain text.
4. `terraform.tfvars` and any file ending in `.auto.tfvars`.
5. It checks the configuration's syntax, references, and types. It does **not** make cloud calls, so it cannot tell whether your credentials, region, or AMI actually exist.
</details>

---

## Summary

- **Input variables** (`var.x`) are the blanks users fill in; give them `type`, `default`, `description`.
- **`validation {}`** rejects bad input early; **`sensitive = true`** hides secrets from output (but not from state).
- **Locals** (`local.x`) are an internal scratchpad for computed/reused values.
- **Outputs** are the receipt - useful results after apply.
- **`.tfvars`** files are per-environment profiles; `terraform.tfvars` and `*.auto.tfvars` auto-load.
- **Precedence:** CLI `-var` > `*.auto.tfvars` > `terraform.tfvars` > `TF_VAR_` env > `default`.
- Run `terraform fmt` and `terraform validate` often.

**Next up -> [Day 5: State Management](../day5/readme.md)** - where Terraform actually *remembers* what it built, and how to keep that memory safe and shared.
