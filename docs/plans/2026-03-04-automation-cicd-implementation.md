# Stage 4: Automation & CI/CD - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automate full deployment and teardown of all GOB layers via GitHub Actions with WIF-based keyless GCP auth.

**Architecture:** New `modules/wif_pool/` wraps WIF Pool+Provider pair. New `gob/automation/` layer creates WIF infrastructure and CI/CD service account. Two GitHub Actions workflows (`terraform-deploy.yml`, `terraform-destroy.yml`) orchestrate layers sequentially with scope selection.

**Tech Stack:** Terraform 1.14.6, Google Provider 7.21.0, GitHub Actions, GCP Workload Identity Federation, OIDC

**Design doc:** `docs/plans/2026-03-04-automation-cicd-design.md`

---

## Task 1: Create `modules/wif_pool/` Module

**Files:**
- Create: `modules/wif_pool/main.tf`
- Create: `modules/wif_pool/variables.tf`
- Create: `modules/wif_pool/outputs.tf`

**Step 1: Create `modules/wif_pool/variables.tf`**

```hcl
variable "name" {
  description = "Workload Identity Pool ID"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "display_name" {
  description = "Display name for the WIF pool"
  type        = string
  default     = ""
}

variable "provider_id" {
  description = "Workload Identity Pool Provider ID"
  type        = string
}

variable "issuer_uri" {
  description = "OIDC Issuer URI (e.g. https://token.actions.githubusercontent.com)"
  type        = string
}

variable "attribute_mapping" {
  description = "Map of attribute mappings from OIDC claims to Google attributes"
  type        = map(string)
}

variable "attribute_condition" {
  description = "CEL expression that must evaluate to true for token exchange to succeed"
  type        = string
  default     = ""
}
```

**Step 2: Create `modules/wif_pool/main.tf`**

```hcl
resource "google_iam_workload_identity_pool" "this" {
  project                   = var.project_id
  workload_identity_pool_id = var.name
  display_name              = var.display_name
}

resource "google_iam_workload_identity_pool_provider" "this" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "${var.display_name} Provider"
  attribute_mapping                  = var.attribute_mapping
  attribute_condition                = var.attribute_condition

  oidc {
    issuer_uri = var.issuer_uri
  }
}
```

**Step 3: Create `modules/wif_pool/outputs.tf`**

```hcl
output "pool_id" {
  description = "Workload Identity Pool ID"
  value       = google_iam_workload_identity_pool.this.id
}

output "pool_name" {
  description = "Workload Identity Pool full resource name"
  value       = google_iam_workload_identity_pool.this.name
}

output "provider_id" {
  description = "Workload Identity Pool Provider ID"
  value       = google_iam_workload_identity_pool_provider.this.id
}

output "provider_name" {
  description = "Workload Identity Pool Provider full resource name"
  value       = google_iam_workload_identity_pool_provider.this.name
}
```

**Step 4: Commit**

```bash
git add modules/wif_pool/
git commit -m "feat(automation): add wif_pool per-resource module"
```

---

## Task 2: Create `gob/automation/` Layer — Boilerplate Files

**Files:**
- Create: `gob/automation/versions.tf`
- Create: `gob/automation/backend.tf`
- Create: `gob/automation/providers.tf`
- Create: `gob/automation/locals.tf`
- Create: `gob/automation/data.tf`

These are identical to other layers (copy from `gob/database/`).

**Step 1: Create `gob/automation/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}
```

**Step 2: Create `gob/automation/backend.tf`**

```hcl
terraform {
  backend "gcs" {
    bucket = "terraform-states-gcs"
    # prefix is set dynamically via: terraform init -backend-config="prefix=CLIENT/ENV/LAYER"
  }
}
```

**Step 3: Create `gob/automation/providers.tf`**

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}
```

**Step 4: Create `gob/automation/locals.tf`**

```hcl
locals {
  # Region short name mapping for resource naming
  region_short_map = {
    "europe-west1"    = "euw1"
    "europe-west2"    = "euw2"
    "europe-west3"    = "euw3"
    "us-central1"     = "usc1"
    "us-east1"        = "use1"
    "us-west1"        = "usw1"
    "asia-east1"      = "ase1"
    "asia-southeast1" = "asse1"
  }

  region_short = lookup(local.region_short_map, var.region, replace(replace(replace(var.region, "europe-", "eu"), "us-", "us"), "asia-", "as"))

  # Unified naming prefix: {client}-{product}-{env}-{region_short}
  naming_prefix = "${var.client_name}-${var.product_name}-${var.environment}-${local.region_short}"
}
```

**Step 5: Create `gob/automation/data.tf`**

```hcl
# No remote state dependencies - automation layer is independent
```

**Step 6: Commit**

```bash
git add gob/automation/versions.tf gob/automation/backend.tf gob/automation/providers.tf gob/automation/locals.tf gob/automation/data.tf
git commit -m "feat(automation): add automation layer boilerplate files"
```

---

## Task 3: Create `gob/automation/` Layer — Variables, Main, Outputs

**Files:**
- Create: `gob/automation/variables.tf`
- Create: `gob/automation/main.tf`
- Create: `gob/automation/outputs.tf`

**Step 1: Create `gob/automation/variables.tf`**

```hcl
# =============================================================================
# Common Variables (same across all layers)
# =============================================================================

variable "client_name" {
  description = "Client/organization name for resource naming"
  type        = string
}

variable "product_name" {
  description = "Product name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

# =============================================================================
# APIs
# =============================================================================

variable "apis" {
  description = "List of GCP APIs to enable"
  type        = list(string)
  default     = []
}

# =============================================================================
# WIF Pools
# =============================================================================

variable "wif_pools" {
  description = "Map of Workload Identity Federation pool configurations. Key = pool name suffix."
  type = map(object({
    display_name        = optional(string, "")
    provider_id         = string
    issuer_uri          = string
    attribute_mapping   = map(string)
    attribute_condition = optional(string, "")
  }))
  default = {}
}

# =============================================================================
# Service Accounts
# =============================================================================

variable "service_accounts" {
  description = "Map of service account configurations for CI/CD. Key = SA name suffix."
  type = map(object({
    display_name = optional(string, "")
    description  = optional(string, "")
    roles        = optional(list(string), [])
    wif_pool_key = string
    github_repo  = string
  }))
  default = {}
}
```

**Step 2: Create `gob/automation/main.tf`**

```hcl
# =============================================================================
# APIs
# =============================================================================

module "apis" {
  for_each = toset(var.apis)
  source   = "../../modules/project_api"

  project_id = var.project_id
  api        = each.value
}

# =============================================================================
# Workload Identity Federation Pools
# =============================================================================

module "wif_pools" {
  for_each = var.wif_pools
  source   = "../../modules/wif_pool"

  name                = "${local.naming_prefix}-wip-${each.key}"
  project_id          = var.project_id
  display_name        = each.value.display_name
  provider_id         = "${local.naming_prefix}-wipp-${each.value.provider_id}"
  issuer_uri          = each.value.issuer_uri
  attribute_mapping   = each.value.attribute_mapping
  attribute_condition = each.value.attribute_condition

  depends_on = [module.apis]
}

# =============================================================================
# Service Accounts
# =============================================================================

module "service_accounts" {
  for_each = var.service_accounts
  source   = "../../modules/service_account"

  name         = "${local.naming_prefix}-sa-${each.key}"
  project_id   = var.project_id
  display_name = each.value.display_name
  description  = each.value.description
  roles        = each.value.roles
}

# =============================================================================
# WIF → Service Account Bindings (allow GitHub to impersonate GSA)
# =============================================================================

resource "google_service_account_iam_member" "wif_sa_binding" {
  for_each = var.service_accounts

  service_account_id = module.service_accounts[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${module.wif_pools[each.value.wif_pool_key].pool_name}/attribute.repository/${each.value.github_repo}"
}
```

**Step 3: Create `gob/automation/outputs.tf`**

```hcl
# --- WIF Pools ---

output "wif_pool_ids" {
  description = "Map of WIF pool key => pool ID"
  value       = { for k, v in module.wif_pools : k => v.pool_id }
}

output "wif_pool_names" {
  description = "Map of WIF pool key => pool full resource name"
  value       = { for k, v in module.wif_pools : k => v.pool_name }
}

output "wif_provider_names" {
  description = "Map of WIF pool key => provider full resource name"
  value       = { for k, v in module.wif_pools : k => v.provider_name }
}

# --- Service Accounts ---

output "service_account_emails" {
  description = "Map of SA key => service account email"
  value       = { for k, v in module.service_accounts : k => v.email }
}

output "service_account_ids" {
  description = "Map of SA key => service account ID"
  value       = { for k, v in module.service_accounts : k => v.id }
}

# --- Naming ---

output "naming_prefix" {
  description = "The computed naming prefix for this environment"
  value       = local.naming_prefix
}
```

**Step 4: Commit**

```bash
git add gob/automation/variables.tf gob/automation/main.tf gob/automation/outputs.tf
git commit -m "feat(automation): add automation layer with WIF pools and CI/CD service accounts"
```

---

## Task 4: Create `gob/automation/tfvars/orel/dev.tfvars`

**Files:**
- Create: `gob/automation/tfvars/orel/dev.tfvars`

**Step 1: Create the tfvars file**

```hcl
# =============================================================================
# Identity & Project
# =============================================================================

client_name  = "orel"
product_name = "gob"
environment  = "dev"
project_id   = "orel-bh-sandbox"
region       = "europe-west1"

# =============================================================================
# APIs
# =============================================================================

apis = [
  "iam.googleapis.com",
  "iamcredentials.googleapis.com",
  "sts.googleapis.com",
  "cloudresourcemanager.googleapis.com",
]

# =============================================================================
# WIF Pools
# =============================================================================

wif_pools = {
  "github" = {
    display_name = "GitHub Actions Pool"
    provider_id  = "github-actions"
    issuer_uri   = "https://token.actions.githubusercontent.com"
    attribute_condition = "assertion.repository_owner == \"BenHur99\""
    attribute_mapping = {
      "google.subject"             = "assertion.sub"
      "attribute.actor"            = "assertion.actor"
      "attribute.repository"       = "assertion.repository"
      "attribute.repository_owner" = "assertion.repository_owner"
    }
  }
}

# =============================================================================
# Service Accounts
# =============================================================================

service_accounts = {
  "cicd" = {
    display_name = "CI/CD GitHub Actions"
    description  = "SA for GitHub Actions WIF-based deployment"
    roles        = ["roles/editor", "roles/servicenetworking.networksAdmin", "roles/resourcemanager.projectIamAdmin"]
    wif_pool_key = "github"
    github_repo  = "BenHur99/GKE_PoC"
  }
}
```

**Step 2: Commit**

```bash
git add gob/automation/tfvars/orel/dev.tfvars
git commit -m "feat(automation): add orel/dev tfvars for automation layer"
```

---

## Task 5: Validate Automation Layer

**Step 1: Run terraform init**

```bash
terraform -chdir=gob/automation init -backend-config="prefix=orel/dev/automation"
```

Expected: `Terraform has been successfully initialized!`

**Step 2: Run terraform validate**

```bash
terraform -chdir=gob/automation validate
```

Expected: `Success! The configuration is valid.`

**Step 3: Run terraform plan (dry run)**

```bash
terraform -chdir=gob/automation plan -var-file=tfvars/orel/dev.tfvars
```

Expected: Plan showing ~8 resources to create:
- 4 APIs (iam, iamcredentials, sts, cloudresourcemanager)
- 1 WIF Pool
- 1 WIF Provider
- 1 Service Account
- 1 IAM Member (roles/editor)
- 1 SA IAM Member (workloadIdentityUser binding)

**Step 4: Fix any validation errors and recommit if needed**

---

## Task 6: Create `.github/workflows/terraform.yml`

**Files:**
- Create: `.github/workflows/terraform.yml`

**Step 1: Create the unified workflow**

> **SHA Pins (verified 2026-03-04):**
> - `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683` = v4.2.2
> - `google-github-actions/auth@c200f3691d83b41bf9bbd8638997a462592937ed` = v2.1.13
> - `hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd` = v3.1.2

Create a single `terraform.yml` that handles plan, apply, and destroy actions using boolean inputs and a `resolve` job for smart dependency tracking. (Refer to the unified pipeline walkthrough artifact for the final YAML content).

**Step 2: Commit**

```bash
git add .github/workflows/terraform.yml
git commit -m "feat(automation): add unified terraform CI/CD workflow"
```

---

## Task 8: Update CLAUDE.md with Stage 4 Status

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add automation layer to directory structure, update roadmap, add run commands, add verification checklist**

Key updates:
- Add `gob/automation/` to directory structure
- Add `modules/wif_pool/` to modules list
- Add `.github/workflows/` to directory structure
- Add automation layer run commands to "How to Run" section
- Update roadmap: Stage 4 = CODE READY, NOT APPLIED
- Add Stage 4 status section with resources and verification checklist
- Add GitHub Secrets setup instructions

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with Stage 4 automation & CI/CD status"
```

---

## Task 9: Final Validation — Full terraform validate on automation layer

**Step 1: Ensure terraform init + validate passes cleanly**

```bash
terraform -chdir=gob/automation init -backend-config="prefix=orel/dev/automation"
terraform -chdir=gob/automation validate
```

Expected: `Success! The configuration is valid.`

**Step 2: Verify all existing layers still validate (no regressions)**

```bash
terraform -chdir=gob/networking validate
terraform -chdir=gob/database validate
terraform -chdir=gob/compute validate
```

Expected: All `Success!`

**Step 3: Final commit if any fixes were needed**

---

## Post-Implementation: Manual Steps

After all code is committed, the user needs to:

1. **Apply automation layer manually (one-time)**
   ```bash
   terraform -chdir=gob/automation init -backend-config="prefix=orel/dev/automation"
   terraform -chdir=gob/automation apply -var-file=tfvars/orel/dev.tfvars
   ```

2. **Get WIF Provider resource name from output**
   ```bash
   terraform -chdir=gob/automation output wif_provider_names
   ```

3. **Get SA email from output**
   ```bash
   terraform -chdir=gob/automation output service_account_emails
   ```

4. **Configure GitHub Secrets** (Settings → Secrets → Actions):
   - `GCP_PROJECT_ID` = `orel-bh-sandbox`
   - `WIF_PROVIDER` = output from step 2
   - `WIF_SERVICE_ACCOUNT` = output from step 3

5. **Push to GitHub** and test workflows from Actions tab

## GitHub Secrets Reference

| Secret | Value | How to get |
|--------|-------|-----------|
| `GCP_PROJECT_ID` | `orel-bh-sandbox` | Known |
| `WIF_PROVIDER` | `projects/PROJECT_NUM/locations/global/workloadIdentityPools/orel-gob-dev-euw1-wip-github/providers/orel-gob-dev-euw1-wipp-github-actions` | `terraform output wif_provider_names` |
| `WIF_SERVICE_ACCOUNT` | `orel-gob-dev-euw1-sa-cicd@orel-bh-sandbox.iam.gserviceaccount.com` | `terraform output service_account_emails` |

## Production Least-Privilege Roles Reference

For production, replace `roles/editor` with:

| Layer | Required Roles |
|-------|---------------|
| Networking | `roles/compute.networkAdmin`, `roles/compute.securityAdmin`, `roles/servicenetworking.networksAdmin` |
| Database | `roles/cloudsql.admin`, `roles/iam.serviceAccountCreator` |
| Compute | `roles/container.admin`, `roles/iam.serviceAccountUser` |
| All layers | `roles/serviceusage.serviceUsageAdmin` (for API enablement) |
