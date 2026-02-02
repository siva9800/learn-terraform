# 🚀 Learn Terraform: Zero to Production

_A Complete 14-Day Hands-on Terraform Course_

This course is designed to take you from **absolute beginner** to **production-ready Terraform engineer**.  
You will not just learn Terraform commands — you will learn **how Terraform is used in industries**.

The course follows a **clear structure**:
- 10 days of core Terraform concepts
- 1 full project day
- 1 full interview-preparation day

---

## 🎯 Course Objectives

By the end of this course, you will be able to:

- Understand **why Terraform exists** and what problems it solves
- Write **clean, readable, and reusable Terraform code**
- Understand Terraform **internals and workflow**
- Manage Terraform **state safely in team environments**
- Design **modular and scalable infrastructure**
- Handle **multiple environments** (dev / prod)
- Apply **security best practices** in Terraform
- Avoid **real-world Terraform anti-patterns**
- Confidently answer **Terraform interview questions**
- Build and explain **one complete Terraform project**

---

## ⏱️ Course Format
- **Audience:** Beginners (cloud basics already completed)  
- **Approach:** Concept → Hands-on → Real-world relevance  

---

## 📅 Course Structure (Day-wise)

---

## 📅 Day 1 – Terraform Foundations & IaC Basics

### You Will Learn
- What is Infrastructure as Code (IaC)
- Problems with manual infrastructure
- Declarative vs Imperative approach
- What Terraform is (and what it is NOT)
- Terraform vs Ansible vs CloudFormation (high-level)
- Terraform alternatives (CloudFormation, ARM/Bicep, Pulumi)

### Hands-On
- Install Terraform on Windows / Linux / Mac
- Verify installation using `terraform version`
- Understand Terraform binary and PATH
- Run first basic Terraform command

### Outcome
You understand **why Terraform is needed and how to install it**.



## 📅 Day 2: The Terraform Core (Syntax, Logic & State)

**Goal:** Understand how Terraform speaks, how it connects to the cloud, and how it remembers what it built.

### 📚 Learning Objectives:

* **HCL Syntax Foundations:** Understanding Blocks vs. Arguments.
* **Provider Ecosystem:** How Terraform interacts with Cloud APIs (AWS, Azure, GCP).
* **Terraform State Deep-Dive:** Understanding the `.tfstate` file as the "Source of Truth."
* **The 4-Step Core Workflow:** Mastering `init`, `plan`, `apply`, and `destroy`.

---

## 📅 Day 3: Practical Deployment & Professional Structure

**Goal:** Build infrastructure, manage resource relationships, and organize code like a DevOps Pro.

### 📚 Learning Objectives:

* **The "First Build" Demo:** Deploying a live EC2 Instance from scratch.
* **Internal Inspection:** Using `terraform console` to query live resource data and the State file.
* **Resource Interdependency:** Mastering **Resource References** (`type.name.attribute`) to link Security Groups and Instances.
* - Terraform dependency graph, Implicit dependencies, Explicit dependencies, Execution order
* **Production File Structure:** Breaking down a single `main.tf` into specialized files:
* `provider.tf`
* `main.tf`
* `variables.tf`
* `outputs.tf`

---

## 📅 Day 4 – Parameterization & Visibility (Variables + Outputs)

Since Variables and Outputs are two sides of the same coin (Inputs vs. Results), combining them makes total sense.

### You Will Learn

* **Input Variables:** types (string, list, map, object), validation rules, and sensitive flags.
* **Variable Precedence:** Which value wins? (CLI args vs. `.tfvars` vs. Env Vars).
* **Output Values:** Extracting data (IPs, IDs, DNS names) for the user or other modules.
* **Locals:** How to use `locals` as private, computed variables to keep code DRY.
* **Code Quality:** Using `terraform fmt` and `terraform validate`.

### Hands-On

* Convert a hardcoded VPC or VM configuration into a parameterized module.
* Create a `terraform.tfvars` file to manage environment-specific settings.
* Output the Public IP of a resource and use `terraform output` to view it.

---

## 📅 Day 5 – The Heart of Terraform: State Management

Since you've already covered how resources relate to each other (dependencies), today should be about how Terraform *remembers* those resources.

### You Will Learn

* **The State File (`terraform.tfstate`):** What is it, and why you should never edit it manually?
* **State Locking:** Preventing two people from breaking infrastructure at the same time.
* **Remote State:** Moving the state file from your laptop to the cloud (S3/GCS/Azure Blob) for collaboration.
* **State Commands:** `terraform state list`, `show`, and `rm`, state import commands

### Hands-On

* **Backend Configuration:** Move a local state file to a Remote Backend (e.g., S3 with DynamoDB for locking).
* **State Inspection:** Use CLI commands to find a specific resource inside the state file without looking at the JSON.
* **Refactoring:** Use `terraform state mv` to rename a resource without destroying it.

### Outcome

You understand **how Terraform tracks real-world infrastructure** and how to **collaborate in a team**.
Here is a **slightly expanded but still high-level glimpse** you can use for **Day 6**:

---

# 📅 Day 6 – Advanced Resource Logic (Meta-Arguments & Lifecycles)

Until now, we have been telling Terraform **what** to create.
Today we learn **how Terraform should behave** when creating, updating, and deleting infrastructure.

On Day 6 we will cover:

### 🔹 **Meta-Arguments – Scaling Infrastructure**

We will learn how to use:

* **`count`** to create multiple identical resources from one block (like 10 web servers).
* **`for_each`** to create multiple similar but distinct resources (like one server per application or one bucket per team).

This helps us eliminate copy-paste and write **dynamic, scalable Terraform code**.

---

### 🔹 **Lifecycle Rules – Making Infrastructure Safe**

We will learn how to control how Terraform treats important resources:

* **`prevent_destroy`** to protect critical resources like databases.
* **`create_before_destroy`** to avoid downtime during replacements.
* **`ignore_changes`** to stop Terraform from fighting changes made by autoscaling or admins.

These rules make Terraform **safe for production environments**.




## 📅 Day 7 – Terraform Modules (Core Concepts)

### You Will Learn
- What modules are
- Root vs child modules
- Inputs and outputs
- Folder structure

### Hands-On
- Create a reusable module
- Call module from root configuration

### Outcome
You can **write reusable Terraform code**.

---

## 📅 Day 8 – Environments, Security & Best Practices

### You Will Learn
- Managing multiple environments
- Terraform workspaces (limitations)
- Folder-based env structure
- Environment-specific tfvars
- Security best practices
- Terraform anti-patterns
- Provisioners (why to avoid)

### Hands-On
- Create dev/prod environments
- Apply security best practices
- Run `terraform fmt` and `terraform validate`

### Outcome
You understand **production-grade Terraform practices**.

---

## 🧱 Day 9 – Terraform Project (Full Session)

### Hands-On Project
- Build a complete Terraform infrastructure
- Use variables, outputs, modules
- Organize code professionally
- Apply best practices

### Outcome
You have **one complete Terraform project**.

---

## 🎤 Day 10 – Terraform Interview Questions (Full Session)

### Hands-On (Interactive)
- Answer interview questions live
- Explain Terraform project end-to-end
- Discuss real-world scenarios
- Mock interview style discussion

### Outcome
You are **interview-ready for Terraform**.

---

## ⭐ Final Outcome of the Course

After completing this course, you will be able to:

- Design Terraform projects from scratch
- Write clean, maintainable Terraform code
- Work safely with Terraform state
- Manage multiple environments
- Confidently face Terraform interviews
- Showcase a real Terraform project

---

🚀 **Welcome to your Terraform journey — from Zero to Production.**
