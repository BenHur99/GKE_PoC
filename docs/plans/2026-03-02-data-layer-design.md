# Data Layer (Stage 2) - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the Data Layer — Cloud SQL PostgreSQL 15 with Private IP and IAM Auth, following the same per-resource module + layer orchestration pattern as the networking layer.

**Architecture:** Two new per-resource modules (`cloud_sql` wrapping instance+database as a tightly-coupled pair, `service_account` wrapping GSA+IAM bindings). A new `gob/database/` layer orchestrates them with `for_each`, reads networking outputs via `terraform_remote_state`, and uses the same 8-file manifest + tfvars pattern.

**Tech Stack:** Terraform >= 1.6, Google Provider >= 6.0, GCS backend (`terraform-states-gcs`), Cloud SQL PostgreSQL 15, IAM Database Authentication.

---

## Task 1: Create `modules/service_account` module

Per-resource module wrapping `google_service_account` + `google_project_iam_member`.

**Files:**
- Create: `modules/service_account/main.tf`
- Create: `modules/service_account/variables.tf`
- Create: `modules/service_account/outputs.tf`

**Step 1: Create `modules/service_account/variables.tf`**

```hcl
variable "name" {
  description = "Service account ID (max 30 chars, used as account_id)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "display_name" {
  description = "Display name for the service account"
  type        = string
  default     = ""
}

variable "description" {
  description = "Description of the service account"
  type        = string
  default     = ""
}

variable "roles" {
  description = "List of IAM roles to grant to this service account at the project level"
  type        = list(string)
  default     = []
}
```

**Step 2: Create `modules/service_account/main.tf`**

```hcl
resource "google_service_account" "this" {
  account_id   = var.name
  project      = var.project_id
  display_name = var.display_name
  description  = var.description
}

resource "google_project_iam_member" "this" {
  for_each = toset(var.roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}
```

**Step 3: Create `modules/service_account/outputs.tf`**

```hcl
output "id" {
  description = "Service account ID"
  value       = google_service_account.this.id
}

output "email" {
  description = "Service account email"
  value       = google_service_account.this.email
}

output "name" {
  description = "Service account fully-qualified name"
  value       = google_service_account.this.name
}
```

**Step 4: Commit**

```bash
git add modules/service_account/
git commit -m "feat(modules): add service_account per-resource module

Wraps google_service_account + google_project_iam_member.
Supports dynamic IAM role assignment via for_each."
```

---

## Task 2: Create `modules/cloud_sql` module

Per-resource module wrapping `google_sql_database_instance` + `google_sql_database` (tightly-coupled pair, same pattern as `cloud_nat` = router + NAT).

**Files:**
- Create: `modules/cloud_sql/main.tf`
- Create: `modules/cloud_sql/variables.tf`
- Create: `modules/cloud_sql/outputs.tf`

**Step 1: Create `modules/cloud_sql/variables.tf`**

```hcl
variable "name" {
  description = "Full name for the Cloud SQL instance (pre-computed by caller)"
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

variable "database_version" {
  description = "Database engine version (e.g. POSTGRES_15)"
  type        = string
}

variable "tier" {
  description = "Machine tier (e.g. db-f1-micro, db-custom-1-3840)"
  type        = string
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "Disk type: PD_SSD or PD_HDD"
  type        = string
  default     = "PD_SSD"
}

variable "availability_type" {
  description = "ZONAL (single zone) or REGIONAL (HA with automatic failover)"
  type        = string
  default     = "ZONAL"
}

variable "network_id" {
  description = "VPC network self_link for private IP connectivity"
  type        = string
}

variable "database_name" {
  description = "Name of the database to create inside the instance"
  type        = string
}

variable "database_flags" {
  description = "Map of database flags (key = flag name, value = flag value)"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Prevent accidental deletion of the instance"
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = false
}

variable "backup_start_time" {
  description = "HH:MM time for daily backup window (UTC)"
  type        = string
  default     = "03:00"
}
```

**Step 2: Create `modules/cloud_sql/main.tf`**

```hcl
resource "google_sql_database_instance" "this" {
  name                = var.name
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    availability_type = var.availability_type

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }

    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.key
        value = database_flags.value
      }
    }

    backup_configuration {
      enabled    = var.backup_enabled
      start_time = var.backup_enabled ? var.backup_start_time : null
    }
  }
}

resource "google_sql_database" "this" {
  name     = var.database_name
  project  = var.project_id
  instance = google_sql_database_instance.this.name
}
```

**Step 3: Create `modules/cloud_sql/outputs.tf`**

```hcl
output "instance_id" {
  description = "Cloud SQL instance ID"
  value       = google_sql_database_instance.this.id
}

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Cloud SQL connection name (project:region:instance) - used by Cloud SQL Proxy"
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.this.private_ip_address
}

output "database_name" {
  description = "Name of the database created"
  value       = google_sql_database.this.name
}
```

**Step 4: Commit**

```bash
git add modules/cloud_sql/
git commit -m "feat(modules): add cloud_sql per-resource module

Wraps google_sql_database_instance + google_sql_database (tightly-coupled pair).
Supports Private IP only, IAM auth via database_flags, configurable tier/disk/backups."
```

---

## Task 3: Create the `gob/database/` layer — scaffold files

Create the 8-file manifest matching the networking layer pattern exactly.

**Files:**
- Create: `gob/database/versions.tf`
- Create: `gob/database/backend.tf`
- Create: `gob/database/providers.tf`
- Create: `gob/database/locals.tf`
- Create: `gob/database/data.tf`
- Create: `gob/database/variables.tf`
- Create: `gob/database/outputs.tf`
- Create: `gob/database/main.tf`
- Create: `gob/database/tfvars/orel/dev.tfvars`

**Step 1: Create `gob/database/versions.tf`** (identical to networking)

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

**Step 2: Create `gob/database/backend.tf`** (identical to networking)

```hcl
terraform {
  backend "gcs" {
    bucket = "terraform-states-gcs"
    # prefix is set dynamically via: terraform init -backend-config="prefix=CLIENT/ENV/LAYER"
  }
}
```

**Step 3: Create `gob/database/providers.tf`** (identical to networking)

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}
```

**Step 4: Create `gob/database/locals.tf`** (identical to networking)

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

**Step 5: Create `gob/database/data.tf`** — reads networking layer outputs

```hcl
# Read networking layer outputs via remote state
data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = "terraform-states-gcs"
    prefix = "${var.client_name}/${var.environment}/networking"
  }
}
```

**Step 6: Create `gob/database/variables.tf`**

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
# Cloud SQL Instances
# =============================================================================

variable "sql_instances" {
  description = "Map of Cloud SQL instance configurations. Key = instance name suffix."
  type = map(object({
    database_version    = string
    tier                = string
    disk_size           = optional(number, 10)
    disk_type           = optional(string, "PD_SSD")
    availability_type   = optional(string, "ZONAL")
    database_name       = string
    deletion_protection = optional(bool, true)
    backup_enabled      = optional(bool, false)
    backup_start_time   = optional(string, "03:00")
    database_flags      = optional(map(string), {})
    vpc_key             = optional(string, "main")
  }))
  default = {}
}

# =============================================================================
# Service Accounts
# =============================================================================

variable "service_accounts" {
  description = "Map of service account configurations. Key = SA name suffix."
  type = map(object({
    display_name = optional(string, "")
    description  = optional(string, "")
    roles        = optional(list(string), [])
  }))
  default = {}
}
```

**Step 7: Create `gob/database/main.tf`**

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
# Cloud SQL Instances
# =============================================================================

module "sql_instances" {
  for_each = var.sql_instances
  source   = "../../modules/cloud_sql"

  name             = "${local.naming_prefix}-sql-${each.key}"
  project_id       = var.project_id
  region           = var.region
  database_version = each.value.database_version
  tier             = each.value.tier
  disk_size        = each.value.disk_size
  disk_type        = each.value.disk_type
  availability_type   = each.value.availability_type
  network_id          = data.terraform_remote_state.networking.outputs.vpc_self_links[each.value.vpc_key]
  database_name       = each.value.database_name
  database_flags      = each.value.database_flags
  deletion_protection = each.value.deletion_protection
  backup_enabled      = each.value.backup_enabled
  backup_start_time   = each.value.backup_start_time

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
```

**Step 8: Create `gob/database/outputs.tf`**

```hcl
# --- Cloud SQL ---

output "sql_instance_ids" {
  description = "Map of SQL instance key => instance ID"
  value       = { for k, v in module.sql_instances : k => v.instance_id }
}

output "sql_instance_names" {
  description = "Map of SQL instance key => instance name"
  value       = { for k, v in module.sql_instances : k => v.instance_name }
}

output "sql_connection_names" {
  description = "Map of SQL instance key => connection name (project:region:instance)"
  value       = { for k, v in module.sql_instances : k => v.connection_name }
}

output "sql_private_ips" {
  description = "Map of SQL instance key => private IP address"
  value       = { for k, v in module.sql_instances : k => v.private_ip }
}

output "sql_database_names" {
  description = "Map of SQL instance key => database name"
  value       = { for k, v in module.sql_instances : k => v.database_name }
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

output "service_account_names" {
  description = "Map of SA key => service account fully-qualified name"
  value       = { for k, v in module.service_accounts : k => v.name }
}

# --- Naming ---

output "naming_prefix" {
  description = "The computed naming prefix for this environment"
  value       = local.naming_prefix
}
```

**Step 9: Create `gob/database/tfvars/orel/dev.tfvars`**

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
  "sqladmin.googleapis.com",
]

# =============================================================================
# Cloud SQL Instances
# =============================================================================

sql_instances = {
  "main" = {
    database_version    = "POSTGRES_15"
    tier                = "db-f1-micro"
    disk_size           = 10
    disk_type           = "PD_HDD"
    availability_type   = "ZONAL"
    database_name       = "boutique"
    deletion_protection = false
    database_flags = {
      "cloudsql.iam_authentication" = "on"
    }
  }
}

# =============================================================================
# Service Accounts
# =============================================================================

service_accounts = {
  "boutique-sql" = {
    display_name = "Boutique Cloud SQL Client"
    description  = "GSA for Online Boutique application - Cloud SQL IAM authentication"
    roles        = ["roles/cloudsql.client"]
  }
}
```

**Step 10: Commit**

```bash
git add gob/database/
git commit -m "feat(database): add database layer with Cloud SQL and service account orchestration

Layer follows same pattern as networking: 8-file manifest + tfvars.
Reads networking outputs via terraform_remote_state for VPC private IP.
Resources: Cloud SQL PostgreSQL 15 (private IP, IAM auth), GSA with cloudsql.client role."
```

---

## Task 4: Validate — init, validate, plan

**Step 1: Terraform init**

Run from project root:
```bash
terraform -chdir=gob/database init -backend-config="prefix=orel/dev/database"
```

Expected: `Terraform has been successfully initialized!`

**Step 2: Terraform validate**

```bash
terraform -chdir=gob/database validate
```

Expected: `Success! The configuration is valid.`

**Step 3: Terraform plan**

```bash
terraform -chdir=gob/database plan -var-file=tfvars/orel/dev.tfvars
```

Expected: Plan shows ~5 resources to create:
- `google_sql_database_instance` (orel-gob-dev-euw1-sql-main)
- `google_sql_database` (boutique)
- `google_service_account` (orel-gob-dev-euw1-sa-boutique-sql)
- `google_project_iam_member` (roles/cloudsql.client)
- `google_project_service` (sqladmin.googleapis.com)

**Note:** This step requires the networking layer to have been applied first (for remote_state to work). If networking hasn't been applied, plan will fail on `terraform_remote_state` — that's expected.

**Step 4: Commit validated state**

```bash
git add -A
git commit -m "chore(database): validated - init and validate successful"
```

---

## Task 5: Update CLAUDE.md with Data Layer status

**Files:**
- Modify: `CLAUDE.md`

Update the directory structure, current status, and resources sections to reflect the new database layer.

**Step 1: Add `cloud_sql` and `service_account` to the modules list in directory structure**

**Step 2: Add `database` layer to gob/ in directory structure**

**Step 3: Update Current Status section with Stage 2 info**

**Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with Stage 2 (Data Layer) status"
```

---

## Resources Created by This Plan

| Resource | Name | Purpose |
|----------|------|---------|
| Cloud SQL Instance | `orel-gob-dev-euw1-sql-main` | PostgreSQL 15, Private IP, IAM Auth |
| SQL Database | `boutique` | Application database |
| Service Account | `orel-gob-dev-euw1-sa-boutique-sql` | GSA for app → SQL IAM auth |
| IAM Binding | `roles/cloudsql.client` → GSA | Allows GSA to connect to Cloud SQL |
| API | `sqladmin.googleapis.com` | Cloud SQL Admin API |

## GCP Console Verification (after apply)

1. **SQL > Instances** — `orel-gob-dev-euw1-sql-main` exists, PostgreSQL 15, db-f1-micro
2. **SQL > Instance > Connections** — Private IP from 10.16.x.x range, NO Public IP
3. **SQL > Instance > Databases** — `boutique` database exists
4. **SQL > Instance > Flags** — `cloudsql.iam_authentication = on`
5. **IAM > Service Accounts** — `orel-gob-dev-euw1-sa-boutique-sql@orel-bh-sandbox.iam.gserviceaccount.com`
6. **IAM > Permissions** — GSA has `roles/cloudsql.client`

## How to Run

```bash
# Init with dynamic backend
terraform -chdir=gob/database init -backend-config="prefix=orel/dev/database"

# Validate
terraform -chdir=gob/database validate

# Plan
terraform -chdir=gob/database plan -var-file=tfvars/orel/dev.tfvars

# Apply
terraform -chdir=gob/database apply -var-file=tfvars/orel/dev.tfvars

# Destroy
terraform -chdir=gob/database destroy -var-file=tfvars/orel/dev.tfvars
```
