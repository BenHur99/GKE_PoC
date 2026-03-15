# GKE PoC — Claude Code Instructions

## About This Project

Production-ready, multi-tenant IaC product for GKE on GCP.
Product name: **GOB** (Google Online Boutique).
Client: **orel**. GCP Project: `orel-bh-sandbox`. Region: `europe-west1`.
Budget: $70/month using ephemeral infrastructure (create morning, destroy evening).

### Owner Context

The owner is a Senior DevOps Tech Lead with 6+ years in Azure/AWS, new to GCP.
This project is a learning exercise — **always explain GCP internals and the "why" behind decisions**.
Communicate in **Hebrew** unless asked otherwise.

## Architecture

### Single Codebase, Multi-Client

One set of `.tf` files per layer under `gob/`. Client/env-specific configuration lives in
`gob/{layer}/tfvars/{client}/{env}.tfvars`. New client = new tfvars folder, no code duplication.

### Per-Resource Modules

Each Terraform module wraps a single GCP resource (or tightly-coupled pair).
Modules are simple wrappers — they receive a pre-computed `name` variable from the caller.
The layer's `main.tf` calls `module "naming"` first, then orchestrates all other modules with `for_each`.
`naming_prefix` and `common_labels` come from `modules/naming/` — not from layer locals.

### Naming Convention

**Format:** `{client}-{product}-{env}-{region_short}-{resource_type}-{name}`
**Example:** `orel-gob-dev-euw1-vpc-main`
Region mapping: `europe-west1` = `euw1`

### Layer-Based State Isolation

Each infrastructure layer has its own Terraform state file.
Layers reference each other via `terraform_remote_state`.
Backend prefix is **dynamic** — set via `terraform init -backend-config="prefix=CLIENT/ENV/LAYER"`.

## How to Run

**IMPORTANT: Run all commands from the project root.**

### Git Bash

```bash
# --- Networking Layer ---
terraform -chdir=gob/networking init -backend-config="prefix=orel/dev/networking"
terraform -chdir=gob/networking validate
terraform -chdir=gob/networking plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/networking apply -var-file=tfvars/orel/dev.tfvars

# --- Database Layer (requires networking to be applied first) ---
terraform -chdir=gob/database init -backend-config="prefix=orel/dev/database"
terraform -chdir=gob/database validate
terraform -chdir=gob/database plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/database apply -var-file=tfvars/orel/dev.tfvars

# --- Compute Layer (requires networking to be applied first) ---
terraform -chdir=gob/compute init -backend-config="prefix=orel/dev/compute"
terraform -chdir=gob/compute validate
terraform -chdir=gob/compute plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/compute apply -var-file=tfvars/orel/dev.tfvars

# --- Automation Layer (one-time manual apply for WIF + CI/CD SA) ---
terraform -chdir=gob/automation init -backend-config="prefix=orel/dev/automation"
terraform -chdir=gob/automation validate
terraform -chdir=gob/automation plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/automation apply -var-file=tfvars/orel/dev.tfvars

# --- Destroy (reverse order!) ---
terraform -chdir=gob/compute destroy -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/database destroy -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/networking destroy -var-file=tfvars/orel/dev.tfvars
```

### PowerShell — IMPORTANT: single quotes around flags with slashes

```powershell
terraform -chdir=gob/networking init '-backend-config=prefix=orel/dev/networking'
terraform -chdir=gob/networking plan '-var-file=tfvars/orel/dev.tfvars'
```

### Switch client/env (re-init)

```bash
terraform -chdir=gob/networking init -reconfigure -backend-config="prefix=OTHER_CLIENT/OTHER_ENV/networking"
```

## Coding Conventions

- All variables that represent collections use `map(object)` with `for_each` (never `list`)
- Even singleton resources (VPC) use `for_each` with a single-entry map for consistency
- Resources referencing other resources use a `vpc_key` field to link via the map key
- `.tfvars` files under `gob/*/tfvars/` are tracked in git (non-secret configuration)
- Secrets go in environment variables or Secret Manager, never in tfvars
- Use `optional()` with defaults in variable type definitions
- Add `validation {}` blocks to all variables with constrained values
- `terraform {}` / `required_providers` goes in `providers.tf` — NOT in `main.tf`
- All resources that support labels receive `labels = module.naming.common_labels`
- Commit messages follow conventional commits: `feat()`, `fix()`, `refactor()`, `docs()`, `chore()`

## Tech Stack

- Terraform >= 1.6 (currently v1.14.6)
- Google Provider >= 6.0 (currently v7.22.0)
- GCS Backend: bucket `terraform-states-gcs`, prefix `{client}/{env}/{layer}`

## Key References

- **Current status & roadmap:** `docs/STATUS.md`
- **Design documents:** `docs/plans/`
- **Rules:** `.claude/rules/` (terraform, git, security, documentation, cicd, context-management)
