# Day 3 - Variables, Outputs, and Locals

> **Goal:** learn how to make Terraform code reusable and configurable so the same files can build a small dev server and a big production one, expose useful results, and stop repeating yourself - using input variables, local values, and outputs.

> **Interactive demo:** [Variable Precedence animation](https://siva9800.github.io/devops-animations/terraform/variable-precedence.html) - watch which value wins when the same variable is set in several places.

---

## What problem does this solve?

On Day 1 you hardcoded everything: the region, the instance size, the tags. That works for one server. But real teams run the *same* infrastructure in several environments - a small cheap one for development, a bigger sturdier one for production - and they must stay identical in shape while differing in a few values.

If your only tool is copy-paste, you end up with `main-dev.tf` and `main-prod.tf` that slowly drift apart until nobody trusts either. A typo in one and not the other becomes an outage.

**Variables, locals, and outputs** fix this. You write one set of `.tf` files with the changeable bits pulled out into **input variables**, compute repeated values once with **locals**, and print the important results (an IP, an instance ID) with **outputs**. Same code, different inputs, no duplication.

---

## Learning Objectives

By the end of Day 3 you will be able to:
- Declare input variables with `type`, `description`, and `default`, and explain why they matter.
- Use every Terraform type: `string`, `number`, `bool`, `list`, `set`, `map`, `object`, and `tuple`.
- Guard inputs with `validation` blocks using `contains(...)` and `can(regex(...))`.
- Mark secrets with `sensitive = true` and understand its one big limitation.
- Provide variable values several ways and know exactly which one wins (precedence).
- Use `.tfvars` files, including auto-loaded ones.
- Expose results with `output` blocks and read them with `terraform output`.
- Remove duplication with `locals`, and explain when to use a local versus a variable.

---

## Real-world analogy: a coffee order form

Think about ordering at a coffee shop.

- **Input variables** are the boxes on the order form: *size*, *milk type*, *number of shots*. The recipe (your `.tf` code) never changes; you just fill the boxes differently. One form, endless drinks.
- **Locals** are shorthand the barista computes once: "a large oat latte" becomes a sticker label they write a single time and reuse on the cup, the receipt, and the queue screen. Defined once, referenced everywhere.
- **Outputs** are the receipt printed at the end: your order number and total. They surface the useful results so you (or the next person in line) can act on them.

**Variables are what you put in, locals are what you work out along the way, and outputs are what you get back.**

---

## Input variables: the `variable {}` block

A variable is a named input to your configuration. You declare it once, then reference it as `var.<name>`.

```hcl
variable "instance_type" {
  type        = string
  description = "EC2 instance size to launch"
  default     = "t2.micro"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, or prod)"
  # no default - Terraform will prompt if it is not provided
}
```

Reference them in a resource:

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  tags = {
    Environment = var.environment
  }
}
```

The three fields you should almost always write:

| Field | What it does |
|---|---|
| `type` | Restricts what values are allowed (a `number` cannot be handed a `string`). Catches mistakes early. |
| `description` | Documents the variable for teammates and for `terraform plan` prompts. Free clarity. |
| `default` | An optional fallback value. If present, the variable is optional; if absent, Terraform prompts (or errors in automation). |

> A variable with no `default` is **required**. If nothing supplies it, Terraform stops and asks.

---

## Variable types

Types are the shape of the data. Terraform has three primitive types and four collection/structural types.

| Type | Holds | Example value |
|---|---|---|
| `string` | Text | `"t2.micro"` |
| `number` | Whole or decimal number | `3` or `1.5` |
| `bool` | True or false | `true` |
| `list(...)` | Ordered items, duplicates allowed, indexed by position | `["a", "b", "a"]` |
| `set(...)` | Unordered unique items, no duplicates, no index | `["a", "b"]` |
| `map(...)` | Key-value pairs, all values the same type | `{ dev = "t2.micro" }` |
| `object({...})` | Fixed-shape record, named fields of mixed types | `{ name = "web", size = 2 }` |
| `tuple([...])` | Fixed-length ordered list of mixed types | `["web", 2, true]` |

```hcl
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "enable_monitoring" {
  type    = bool
  default = false
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "allowed_ports" {
  type    = set(number)
  default = [22, 80, 443]
}

variable "instance_sizes" {
  type = map(string)
  default = {
    dev  = "t2.micro"
    prod = "t3.large"
  }
}

variable "app_config" {
  type = object({
    name     = string
    replicas = number
    public   = bool
  })
  default = {
    name     = "web"
    replicas = 2
    public   = true
  }
}

variable "server_spec" {
  type    = tuple([string, number, bool])
  default = ["web", 2, true]
}
```

Rules of thumb: use a `list` when order matters or duplicates are allowed, a `set` when items must be unique and order does not matter, a `map` for lookups by key, an `object` for a fixed record of named fields, and a `tuple` only when you truly need mixed types in a fixed order (rare).

---

## Validation blocks: reject bad input early

A `validation` block runs a `condition` when the value is set. If the condition is `false`, Terraform stops and shows your `error_message`. This turns confusing downstream failures into clear, immediate ones.

```hcl
variable "instance_type" {
  type        = string
  description = "EC2 instance size"
  default     = "t2.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type must be one of: t2.micro, t3.micro, t3.small."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  type        = string
  description = "Lowercase project slug, letters and dashes only"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "project_name must be lowercase, start with a letter, and contain only letters, numbers, and dashes."
  }
}
```

Two patterns you will reuse constantly:

- `contains([...], var.x)` - "is this value one of an allowed list?" Perfect for enums like environment or instance size.
- `can(regex("...", var.x))` - `regex(...)` errors if the pattern does not match; wrapping it in `can(...)` turns that error into a clean `true`/`false`, so the pattern becomes a pass/fail test for naming rules.

---

## Sensitive variables

Some inputs are secrets - a database password, an API token. Mark them `sensitive` so Terraform stops printing them in plan and apply output.

```hcl
variable "db_password" {
  type        = string
  description = "Master password for the database"
  sensitive   = true
}
```

Now `terraform plan` shows `(sensitive value)` instead of the real password, and outputs derived from it are masked too.

> **Important limitation:** `sensitive = true` only hides the value from *console output*. The value is still written in **plaintext into the state file** (`terraform.tfstate`). Anyone who can read the state file can read the secret. This is why state files must be encrypted and never committed to Git. We tackle real secret handling and state security on **Day 16**.

---

## Providing values, and which one wins (precedence)

You can set a variable in several places. When more than one place sets the same variable, Terraform uses a strict priority order. **Higher on this list beats lower:**

| Priority | Source | Notes |
|---|---|---|
| 1 (highest) | Command line `-var` and `-var-file` | With several on one command line, the **last one wins** |
| 2 | `*.auto.tfvars` / `*.auto.tfvars.json` | Auto-loaded; processed in **alphabetical** filename order |
| 3 | `terraform.tfvars.json` | Auto-loaded |
| 4 | `terraform.tfvars` | Auto-loaded |
| 5 | Environment variables `TF_VAR_<name>` | e.g. `TF_VAR_region=us-west-2` |
| 6 (lowest) | The `default` in the `variable` block | The fallback if nothing else sets it |

```mermaid
flowchart TD
    A["1. CLI: -var / -var-file<br/>(later on the line wins)"] --> B["2. *.auto.tfvars<br/>(alphabetical order)"]
    B --> C["3. terraform.tfvars.json"]
    C --> D["4. terraform.tfvars"]
    D --> E["5. Env vars TF_VAR_name"]
    E --> F["6. default in variable block"]
    style A fill:#e8f5e9,stroke:#2e7d32
    style B fill:#f1f8e9,stroke:#558b2f
    style C fill:#fff8e1,stroke:#f9a825
    style D fill:#fff3e0,stroke:#e65100
    style E fill:#fce4ec,stroke:#c2185b
    style F fill:#ffebee,stroke:#c62828
```

Read the diagram top to bottom as strongest to weakest. If you set `region` on the command line with `-var`, it overrides the same variable set in every file, in the environment, and in the default.

Examples of each source:

```bash
# 1. Command line (highest). Later -var wins over earlier -var:
terraform apply -var="region=us-west-2" -var="environment=prod"

# 1. A custom file, explicitly loaded:
terraform apply -var-file="prod.tfvars"

# 5. Environment variable:
export TF_VAR_region=eu-west-1     # macOS/Linux
$env:TF_VAR_region = "eu-west-1"   # Windows PowerShell
terraform apply
```

---

## `.tfvars` files

A `.tfvars` file is just a list of `name = value` pairs. It sets values; it does not declare variables (those live in `variable` blocks).

```hcl
# terraform.tfvars  - auto-loaded, no flag needed
region         = "us-east-1"
environment    = "dev"
instance_type  = "t2.micro"
instance_count = 1
```

Three kinds worth knowing:

| File | Auto-loaded? | How it is used |
|---|---|---|
| `terraform.tfvars` (or `.json`) | Yes | Loaded automatically on every `plan`/`apply`. The default place to put values. |
| `*.auto.tfvars` | Yes | Any file ending in `.auto.tfvars` is auto-loaded, alphabetically. Handy for splitting config. |
| `prod.tfvars` (custom name) | No | **Not** auto-loaded. You must pass it: `terraform apply -var-file="prod.tfvars"`. |

A common real-world pattern is one custom file per environment:

```hcl
# dev.tfvars
environment    = "dev"
instance_type  = "t2.micro"
instance_count = 1

# prod.tfvars
environment    = "prod"
instance_type  = "t3.large"
instance_count = 3
```

```bash
terraform apply -var-file="dev.tfvars"    # small dev stack
terraform apply -var-file="prod.tfvars"   # big prod stack, same code
```

> Because `.tfvars` files often hold environment-specific and sometimes sensitive values, keep them out of Git (`*.tfvars` was in the Day 1 `.gitignore`).

---

## Output values: the receipt

An `output` block exposes a value after `apply` - an IP address, an instance ID, a DNS name - so you can read it, or so a parent module can consume it.

```hcl
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP address of the web server"
  value       = aws_instance.web.public_ip
}

output "db_connection" {
  description = "Database connection string"
  value       = "postgres://admin:${var.db_password}@db.example.com"
  sensitive   = true # masks it in output; it is still in state
}
```

Reading outputs:

```bash
terraform output              # print all outputs
terraform output public_ip    # print just one
terraform output -raw public_ip   # raw value, no quotes - good for scripts
terraform output -json        # machine-readable, for pipelines
```

**Why outputs matter:** they surface the values you actually need after building (no digging in the AWS console), and they are how one Terraform **module** hands data to another - a networking module outputs a subnet ID that a server module takes as input. Modules are Day 8; outputs are the plumbing that connects them.

---

## Local values: define once, reuse everywhere (DRY)

A `locals` block holds computed or repeated values. Reference them as `local.<name>`. Unlike variables, locals **cannot** be set from outside - they are internal helpers you calculate from variables and other locals.

```hcl
locals {
  # A naming prefix built once and reused everywhere
  name_prefix = "${var.project_name}-${var.environment}"

  # Tags every resource should carry, merged from a common base
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.extra_tags
  )
}
```

Use them so a change happens in one place:

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web"
  })
}
```

**Locals vs variables** - the key distinction:

| | Variable | Local |
|---|---|---|
| Set from outside? | Yes - CLI, `.tfvars`, env, prompt | No - computed internally |
| Purpose | External **input** knob | Internal **computed/repeated** value |
| Reference | `var.name` | `local.name` |
| Good for | Values that differ per environment | Naming prefixes, merged tags, expressions used many times |

If a value comes from *outside* your config, it is a variable. If you *compute* it inside your config, it is a local.

---

## Putting it all together

A single, valid AWS example that ties variables, validation, locals, and outputs onto one EC2 instance - with a fresh AMI looked up rather than hardcoded.

```hcl
# ---- variables.tf ----
variable "region" {
  type        = string
  description = "AWS region to deploy into"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Lowercase project slug"
  default     = "webapp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "project_name must be lowercase letters, numbers, and dashes."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance size"
  default     = "t2.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small", "t3.large"], var.instance_type)
    error_message = "instance_type must be one of the approved sizes."
  }
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to merge onto resources"
  default     = {}
}

# ---- main.tf ----
provider "aws" {
  region = var.region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.extra_tags
  )
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web"
  })
}

# ---- outputs.tf ----
output "instance_id" {
  description = "ID of the web instance"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP of the web instance"
  value       = aws_instance.web.public_ip
}

output "name_prefix" {
  description = "Naming prefix used for resources"
  value       = local.name_prefix
}
```

The convention above - splitting into `variables.tf`, `main.tf`, and `outputs.tf` - is standard practice. Terraform loads all `.tf` files in a folder together, so the split is purely for human readability.

```mermaid
flowchart LR
    V["Input variables<br/>region, environment,<br/>instance_type"] --> L["Locals<br/>name_prefix,<br/>common_tags"]
    V --> R["aws_instance.web"]
    L --> R
    D["data.aws_ami<br/>(fresh AMI lookup)"] --> R
    R --> O["Outputs<br/>instance_id, public_ip"]
    style V fill:#e3f2fd,stroke:#1565c0
    style L fill:#fff3e0,stroke:#e65100
    style D fill:#f3e5f5,stroke:#6a1b9a
    style R fill:#e8f5e9,stroke:#2e7d32
    style O fill:#fce4ec,stroke:#c2185b
```

---

## Common Mistakes

1. **Confusing a variable with a local.** If it comes from outside, it is a `variable` (`var.x`). If you compute it inside, it is a `local` (`local.x`). You cannot set a local from the command line.
2. **Expecting `sensitive = true` to secure a value.** It only masks console output. The value is still plaintext in the state file. Encrypt and protect state (Day 16).
3. **Assuming a custom `.tfvars` file auto-loads.** Only `terraform.tfvars` and `*.auto.tfvars` are automatic. A file like `prod.tfvars` needs `-var-file="prod.tfvars"`.
4. **Getting precedence backwards.** A `-var` on the command line overrides everything, including files. The `default` in the block is the weakest source, used only when nothing else sets the value.
5. **Committing `.tfvars` to Git.** They often hold environment-specific or sensitive values. Keep them ignored, as set up on Day 1.
6. **Skipping `type` and `description`.** Untyped variables accept anything and fail confusingly later. A one-line type and description saves hours.

---

## Hands-On Lab: one config, two environments

```bash
# 1. Make a project folder and split files
mkdir tf-vars-lab && cd tf-vars-lab
# Create variables.tf, main.tf, outputs.tf from the combined example above

# 2. Create two environment files
#    dev.tfvars:
#      environment    = "dev"
#      instance_type  = "t2.micro"
#    prod.tfvars:
#      environment    = "prod"
#      instance_type  = "t3.large"

# 3. Tidy, check, init
terraform fmt
terraform validate
terraform init

# 4. Plan the DEV stack and read the outputs it will produce
terraform plan -var-file="dev.tfvars"

# 5. Build DEV, then read an output
terraform apply -var-file="dev.tfvars"
terraform output public_ip

# 6. Try to break validation on purpose (should be rejected):
terraform plan -var-file="dev.tfvars" -var="environment=production"

# 7. Override on the command line - it wins over the file:
terraform plan -var-file="dev.tfvars" -var="instance_type=t3.small"

# 8. Clean up
terraform destroy -var-file="dev.tfvars"
```

**Success check:** DEV builds a `t2.micro` named `webapp-dev-web`; step 6 fails with your `environment` error message; in step 7 the plan shows `t3.small`, proving the CLI beat the file.

---

## Quick Self-Check

1. What are the three fields you should almost always give a `variable`, and what does each do?
2. Which wins if `region` is set both by `-var` on the command line and in `terraform.tfvars`? Why?
3. What does `sensitive = true` actually protect - and what does it not protect?
4. When do you need `-var-file`, and when is a `.tfvars` file loaded automatically?
5. Give one clear difference between a variable and a local.

<details>
<summary>Answers</summary>

1. `type` (restricts allowed values and catches wrong shapes), `description` (documents it for teammates and prompts), and `default` (an optional fallback; without it the variable is required).
2. The command-line `-var` wins. CLI is the highest-priority source; auto-loaded files like `terraform.tfvars` sit lower, and the block `default` is lowest.
3. It masks the value in `plan`/`apply` console output (and in outputs derived from it). It does **not** encrypt or hide the value in the state file, where it stays plaintext.
4. A custom-named file such as `prod.tfvars` needs `-var-file`. Files named `terraform.tfvars`/`terraform.tfvars.json` and any `*.auto.tfvars` are loaded automatically.
5. A variable is an external input you can set from CLI, files, or env (`var.x`); a local is computed internally and cannot be set from outside (`local.x`).
</details>

---

## Summary

- Input variables (`variable {}`) pull the changeable bits out of your code so the same files serve dev and prod - your coffee order form.
- Terraform types run from primitives (`string`, `number`, `bool`) to collections and structures (`list`, `set`, `map`, `object`, `tuple`).
- `validation` blocks reject bad input early using `contains([...], var.x)` and `can(regex(...))`.
- `sensitive = true` masks console output only; the value still lands in state (Day 16).
- Precedence, strongest to weakest: CLI `-var`/`-var-file` > `*.auto.tfvars` > `terraform.tfvars.json` > `terraform.tfvars` > `TF_VAR_` env > block `default`.
- `terraform.tfvars` and `*.auto.tfvars` auto-load; custom files need `-var-file`.
- Outputs (`output {}`) surface results and pass data between modules; locals (`locals {}`) compute repeated values once for DRY code.

**Next up ->** [Day 4 - State Fundamentals](../day04-state-fundamentals/notes.md)
