# Gold Standard Hardening — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Elevate all Terraform modules and layers to enterprise-grade Gold Standard with security hardening, validation, testing, and DRY principles.

**Architecture:** 5 phases applied incrementally — security first, then module quality, testing, multi-env, and skills prep. Each phase commits independently. All changes on `feat/gold-standard-hardening` branch.

**Tech Stack:** Terraform >= 1.6, Google Provider >= 6.0, GCS Backend, native `terraform test`

---

## Task 1: Add `terraform {}` blocks to all 13 modules

**Files:**
- Modify: `modules/vpc/main.tf`
- Modify: `modules/subnet/main.tf`
- Modify: `modules/firewall_rule/main.tf`
- Modify: `modules/cloud_nat/main.tf`
- Modify: `modules/psa/main.tf`
- Modify: `modules/static_ip/main.tf`
- Modify: `modules/project_api/main.tf`
- Modify: `modules/cloud_sql/main.tf`
- Modify: `modules/service_account/main.tf`
- Modify: `modules/gke_cluster/main.tf`
- Modify: `modules/gke_node_pool/main.tf`
- Modify: `modules/wif_pool/main.tf`
- Modify: `modules/wi_binding/main.tf`

**Step 1: Add terraform block to each module's main.tf**

Add to the TOP of each module's `main.tf`:

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

**Step 2: Run validation on all layers**

```bash
terraform -chdir=gob/networking validate
terraform -chdir=gob/database validate
terraform -chdir=gob/compute validate
terraform -chdir=gob/automation validate
```

Expected: All 4 pass.

**Step 3: Commit**

```bash
git add modules/
git commit -m "feat(modules): add terraform required_providers blocks to all 13 modules"
```

---

## Task 2: Create shared `naming` module to eliminate DRY violation

**Files:**
- Create: `modules/naming/main.tf`
- Create: `modules/naming/variables.tf`
- Create: `modules/naming/outputs.tf`
- Modify: `gob/networking/locals.tf`
- Modify: `gob/networking/main.tf`
- Modify: `gob/database/locals.tf`
- Modify: `gob/database/main.tf`
- Modify: `gob/compute/locals.tf`
- Modify: `gob/compute/main.tf`
- Modify: `gob/automation/locals.tf`
- Modify: `gob/automation/main.tf`

**Step 1: Create modules/naming/variables.tf**

```hcl
variable "client_name" {
  description = "Client name (e.g. orel)"
  type        = string
}

variable "product_name" {
  description = "Product name (e.g. gob)"
  type        = string
}

variable "environment" {
  description = "Environment (e.g. dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "GCP region (e.g. europe-west1)"
  type        = string
}
```

**Step 2: Create modules/naming/main.tf**

```hcl
locals {
  region_short_map = {
    "europe-west1"      = "euw1"
    "europe-west2"      = "euw2"
    "europe-west3"      = "euw3"
    "us-central1"       = "usc1"
    "us-east1"          = "use1"
    "us-east4"          = "use4"
    "us-west1"          = "usw1"
    "me-west1"          = "mew1"
    "asia-east1"        = "ase1"
    "asia-southeast1"   = "asse1"
    "australia-southeast1" = "ause1"
  }

  region_short = lookup(local.region_short_map, var.region, replace(var.region, "-", ""))
  prefix       = "${var.client_name}-${var.product_name}-${var.environment}-${local.region_short}"
}
```

**Step 3: Create modules/naming/outputs.tf**

```hcl
output "prefix" {
  description = "Naming prefix: {client}-{product}-{env}-{region_short}"
  value       = local.prefix
}

output "region_short" {
  description = "Short region code (e.g. euw1)"
  value       = local.region_short
}
```

**Step 4: Update all 4 layer locals.tf and main.tf**

In each layer's `main.tf`, add at the top (before other modules):

```hcl
module "naming" {
  source       = "../../modules/naming"
  client_name  = var.client_name
  product_name = var.product_name
  environment  = var.environment
  region       = var.region
}
```

In each layer's `locals.tf`, replace the full content with:

```hcl
locals {
  naming_prefix = module.naming.prefix
}
```

**Step 5: Run validation on all layers**

```bash
terraform -chdir=gob/networking validate
terraform -chdir=gob/database validate
terraform -chdir=gob/compute validate
terraform -chdir=gob/automation validate
```

Expected: All 4 pass.

**Step 6: Commit**

```bash
git add modules/naming/ gob/networking/locals.tf gob/networking/main.tf gob/database/locals.tf gob/database/main.tf gob/compute/locals.tf gob/compute/main.tf gob/automation/locals.tf gob/automation/main.tf
git commit -m "refactor(modules): extract shared naming module to eliminate DRY violation"
```

---

## Task 3: Add GCP labels system

**Files:**
- Modify: `modules/vpc/main.tf`, `modules/vpc/variables.tf`
- Modify: `modules/subnet/main.tf`, `modules/subnet/variables.tf`
- Modify: `modules/firewall_rule/main.tf`, `modules/firewall_rule/variables.tf`
- Modify: `modules/cloud_nat/main.tf`, `modules/cloud_nat/variables.tf`
- Modify: `modules/static_ip/main.tf`, `modules/static_ip/variables.tf`
- Modify: `modules/cloud_sql/main.tf`, `modules/cloud_sql/variables.tf`
- Modify: `modules/service_account/main.tf`, `modules/service_account/variables.tf`
- Modify: `modules/gke_cluster/main.tf`, `modules/gke_cluster/variables.tf`
- Modify: `modules/gke_node_pool/main.tf`, `modules/gke_node_pool/variables.tf`
- Modify: `modules/naming/main.tf`, `modules/naming/variables.tf`, `modules/naming/outputs.tf`
- Modify: all 4 layer `main.tf` files
- Modify: all 4 layer tfvars files

**Note:** `google_compute_firewall`, `google_compute_router`, `google_compute_router_nat`, `google_project_service`, `google_iam_workload_identity_pool`, `google_service_account_iam_member` do NOT support labels. Only add labels to resources that support them.

**Resources that support labels:**
- `google_compute_network` (VPC) ✓
- `google_compute_subnetwork` (Subnet) ✓ (but only purpose=PRIVATE)
- `google_compute_address` (Static IP) ✓
- `google_sql_database_instance` (Cloud SQL) ✓ via `settings.user_labels`
- `google_container_cluster` (GKE) ✓ via `resource_labels`
- `google_container_node_pool` (Node Pool) ✓ via `node_config.resource_labels`
- `google_service_account` — NO labels attribute (only description)

**Step 1: Add common_labels output to naming module**

Add to `modules/naming/variables.tf`:

```hcl
variable "layer" {
  description = "Infrastructure layer name (networking, database, compute, automation)"
  type        = string
}

variable "extra_labels" {
  description = "Additional labels to merge with common labels"
  type        = map(string)
  default     = {}
}
```

Add to `modules/naming/main.tf` inside locals:

```hcl
  common_labels = merge({
    client      = var.client_name
    product     = var.product_name
    environment = var.environment
    region      = local.region_short
    managed_by  = "terraform"
    layer       = var.layer
  }, var.extra_labels)
```

Add to `modules/naming/outputs.tf`:

```hcl
output "common_labels" {
  description = "Common GCP labels for all resources"
  value       = local.common_labels
}
```

**Step 2: Update each layer's naming module call**

Add `layer = "networking"` (or database/compute/automation) to each layer's module "naming" block in main.tf.

**Step 3: Add labels variable to modules that support them**

For each supporting module, add to `variables.tf`:

```hcl
variable "labels" {
  description = "GCP labels to apply to the resource"
  type        = map(string)
  default     = {}
}
```

And in `main.tf`, add the labels attribute:

- **VPC** (`modules/vpc/main.tf`): Add `labels = var.labels` inside resource block (not in description - as its own attribute)
- **Subnet** (`modules/subnet/main.tf`): No direct labels attribute on google_compute_subnetwork — SKIP
- **Static IP** (`modules/static_ip/main.tf`): Add `labels = var.labels`
- **Cloud SQL** (`modules/cloud_sql/main.tf`): Add `user_labels = var.labels` inside `settings {}` block
- **GKE Cluster** (`modules/gke_cluster/main.tf`): Add `resource_labels = var.labels`
- **GKE Node Pool** (`modules/gke_node_pool/main.tf`): Add `resource_labels = var.labels` inside `node_config {}`

**Step 4: Pass labels from layers to modules**

In each layer's `main.tf`, add `labels = module.naming.common_labels` to all module calls that support labels.

Example for networking layer's VPC:
```hcl
module "vpcs" {
  for_each = var.vpcs
  source   = "../../modules/vpc"
  name     = "${local.naming_prefix}-vpc-${each.key}"
  project_id = var.project_id
  labels     = module.naming.common_labels
}
```

**Step 5: Run validation**

```bash
terraform -chdir=gob/networking validate
terraform -chdir=gob/database validate
terraform -chdir=gob/compute validate
terraform -chdir=gob/automation validate
```

**Step 6: Commit**

```bash
git add modules/ gob/
git commit -m "feat(modules): add GCP labels system for cost tracking and resource organization"
```

---

## Task 4: IAM hardening — replace roles/editor

**Files:**
- Modify: `gob/automation/tfvars/orel/dev.tfvars`

**Step 1: Replace roles/editor with specific roles**

In `gob/automation/tfvars/orel/dev.tfvars`, replace the `roles` list in the `cicd` service account:

```hcl
    roles = [
      "roles/container.admin",
      "roles/compute.admin",
      "roles/cloudsql.admin",
      "roles/storage.admin",
      "roles/servicenetworking.networksAdmin",
      "roles/resourcemanager.projectIamAdmin",
      "roles/iam.serviceAccountAdmin"
    ]
```

**Step 2: Run validation**

```bash
terraform -chdir=gob/automation validate
```

**Step 3: Commit**

```bash
git add gob/automation/tfvars/orel/dev.tfvars
git commit -m "fix(automation): replace roles/editor with least-privilege IAM roles for CI/CD SA"
```

---

## Task 5: GKE security hardening

**Files:**
- Modify: `modules/gke_cluster/main.tf`
- Modify: `modules/gke_cluster/variables.tf`
- Modify: `gob/compute/variables.tf`
- Modify: `gob/compute/tfvars/orel/dev.tfvars`

**Step 1: Add security variables to modules/gke_cluster/variables.tf**

```hcl
variable "enable_network_policy" {
  description = "Enable Kubernetes NetworkPolicy enforcement (Calico)"
  type        = bool
  default     = true
}

variable "enable_shielded_nodes" {
  description = "Enable Shielded GKE Nodes (secure boot, integrity monitoring)"
  type        = bool
  default     = true
}

variable "logging_service" {
  description = "Logging service: logging.googleapis.com/kubernetes or none"
  type        = string
  default     = "logging.googleapis.com/kubernetes"
}

variable "monitoring_service" {
  description = "Monitoring service: monitoring.googleapis.com/kubernetes or none"
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"
}

variable "maintenance_window_start_time" {
  description = "Daily maintenance window start time in UTC (HH:MM format)"
  type        = string
  default     = "02:00"
}
```

**Step 2: Add security config to modules/gke_cluster/main.tf**

Add inside the `google_container_cluster` resource, after the `release_channel` block:

```hcl
  # Network Policy — enables Kubernetes NetworkPolicy enforcement via Calico
  network_policy {
    enabled = var.enable_network_policy
  }

  # Shielded Nodes — integrity monitoring and secure boot
  enable_shielded_nodes = var.enable_shielded_nodes

  # Logging and Monitoring
  logging_service    = var.logging_service
  monitoring_service = var.monitoring_service

  # Maintenance Window — controls when GKE can perform automatic maintenance
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_window_start_time
    }
  }
```

**Step 3: Add variables to compute layer**

Add to the `gke_clusters` variable object type in `gob/compute/variables.tf`:

```hcl
    enable_network_policy           = optional(bool, true)
    enable_shielded_nodes           = optional(bool, true)
    logging_service                 = optional(string, "logging.googleapis.com/kubernetes")
    monitoring_service              = optional(string, "monitoring.googleapis.com/kubernetes")
    maintenance_window_start_time   = optional(string, "02:00")
```

**Step 4: Pass variables in compute layer main.tf**

Add to the `module "gke_clusters"` call in `gob/compute/main.tf`:

```hcl
    enable_network_policy           = each.value.enable_network_policy
    enable_shielded_nodes           = each.value.enable_shielded_nodes
    logging_service                 = each.value.logging_service
    monitoring_service              = each.value.monitoring_service
    maintenance_window_start_time   = each.value.maintenance_window_start_time
```

**Step 5: Add comment in dev.tfvars explaining defaults**

Add to `gob/compute/tfvars/orel/dev.tfvars` inside the "main" cluster:

```hcl
      # Security hardening (all default to secure values, override here only if needed)
      # enable_network_policy = true
      # enable_shielded_nodes = true
      # logging_service       = "logging.googleapis.com/kubernetes"
      # monitoring_service    = "monitoring.googleapis.com/kubernetes"
      # maintenance_window_start_time = "02:00"
```

**Step 6: Run validation**

```bash
terraform -chdir=gob/compute validate
```

**Step 7: Commit**

```bash
git add modules/gke_cluster/ gob/compute/
git commit -m "feat(compute): add GKE security hardening — network policy, shielded nodes, logging, maintenance"
```

---

## Task 6: Mark sensitive outputs

**Files:**
- Modify: `modules/gke_cluster/outputs.tf`
- Modify: `modules/cloud_sql/outputs.tf`
- Modify: `gob/compute/outputs.tf`
- Modify: `gob/database/outputs.tf`

**Step 1: Mark module outputs**

In `modules/gke_cluster/outputs.tf`, add `sensitive = true` to the `endpoint` output:

```hcl
output "endpoint" {
  description = "GKE cluster API endpoint"
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}
```

In `modules/cloud_sql/outputs.tf`, add `sensitive = true` to `private_ip` and `connection_name`:

```hcl
output "connection_name" {
  description = "Cloud SQL connection name (project:region:instance) - used by Cloud SQL Proxy"
  value       = google_sql_database_instance.this.connection_name
  sensitive   = true
}

output "private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.this.private_ip_address
  sensitive   = true
}
```

**Step 2: Mark layer outputs**

In `gob/compute/outputs.tf`, add `sensitive = true` to `cluster_endpoints`:

```hcl
output "cluster_endpoints" {
  description = "Map of GKE cluster endpoints"
  value       = { for k, v in module.gke_clusters : k => v.endpoint }
  sensitive   = true
}
```

In `gob/database/outputs.tf`, add `sensitive = true` to `sql_private_ips` and `sql_connection_names`:

```hcl
output "sql_private_ips" {
  description = "Map of Cloud SQL private IPs"
  value       = { for k, v in module.sql_instances : k => v.private_ip }
  sensitive   = true
}

output "sql_connection_names" {
  description = "Map of Cloud SQL connection names"
  value       = { for k, v in module.sql_instances : k => v.connection_name }
  sensitive   = true
}
```

**Step 3: Run validation**

```bash
terraform -chdir=gob/compute validate
terraform -chdir=gob/database validate
```

**Step 4: Commit**

```bash
git add modules/gke_cluster/outputs.tf modules/cloud_sql/outputs.tf gob/compute/outputs.tf gob/database/outputs.tf
git commit -m "fix(security): mark sensitive outputs — cluster endpoints, SQL IPs, connection names"
```

---

## Task 7: Add `validation {}` blocks to module variables

**Files:**
- Modify: `modules/firewall_rule/variables.tf`
- Modify: `modules/static_ip/variables.tf`
- Modify: `modules/cloud_nat/variables.tf`
- Modify: `modules/cloud_sql/variables.tf`
- Modify: `modules/gke_cluster/variables.tf`
- Modify: `modules/gke_node_pool/variables.tf`
- Modify: `modules/subnet/variables.tf`
- Modify: `modules/naming/variables.tf`

**Step 1: Add validations**

**modules/firewall_rule/variables.tf:**

```hcl
variable "direction" {
  description = "Direction: INGRESS or EGRESS"
  type        = string
  default     = "INGRESS"

  validation {
    condition     = contains(["INGRESS", "EGRESS"], var.direction)
    error_message = "Direction must be INGRESS or EGRESS."
  }
}

variable "action" {
  description = "Action: allow or deny"
  type        = string

  validation {
    condition     = contains(["allow", "deny"], var.action)
    error_message = "Action must be allow or deny."
  }
}

variable "protocol" {
  description = "Protocol: tcp, udp, icmp, all"
  type        = string

  validation {
    condition     = contains(["tcp", "udp", "icmp", "all"], var.protocol)
    error_message = "Protocol must be tcp, udp, icmp, or all."
  }
}

variable "priority" {
  description = "Rule priority (lower = higher priority)"
  type        = number
  default     = 1000

  validation {
    condition     = var.priority >= 0 && var.priority <= 65535
    error_message = "Priority must be between 0 and 65535."
  }
}
```

**modules/static_ip/variables.tf:**

```hcl
variable "address_type" {
  description = "Address type: EXTERNAL or INTERNAL"
  type        = string
  default     = "EXTERNAL"

  validation {
    condition     = contains(["EXTERNAL", "INTERNAL"], var.address_type)
    error_message = "Address type must be EXTERNAL or INTERNAL."
  }
}

variable "network_tier" {
  description = "Network tier: PREMIUM or STANDARD"
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["PREMIUM", "STANDARD"], var.network_tier)
    error_message = "Network tier must be PREMIUM or STANDARD."
  }
}
```

**modules/cloud_nat/variables.tf:**

```hcl
variable "nat_ip_allocate_option" {
  description = "How external IPs are allocated: AUTO_ONLY or MANUAL_ONLY"
  type        = string
  default     = "AUTO_ONLY"

  validation {
    condition     = contains(["AUTO_ONLY", "MANUAL_ONLY"], var.nat_ip_allocate_option)
    error_message = "NAT IP allocate option must be AUTO_ONLY or MANUAL_ONLY."
  }
}

variable "log_filter" {
  description = "NAT log filter: ERRORS_ONLY, TRANSLATIONS_ONLY, ALL"
  type        = string
  default     = "ERRORS_ONLY"

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.log_filter)
    error_message = "Log filter must be ERRORS_ONLY, TRANSLATIONS_ONLY, or ALL."
  }
}
```

**modules/cloud_sql/variables.tf:**

```hcl
variable "disk_type" {
  description = "Disk type: PD_SSD or PD_HDD"
  type        = string
  default     = "PD_SSD"

  validation {
    condition     = contains(["PD_SSD", "PD_HDD"], var.disk_type)
    error_message = "Disk type must be PD_SSD or PD_HDD."
  }
}

variable "availability_type" {
  description = "ZONAL (single zone) or REGIONAL (HA with automatic failover)"
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "Availability type must be ZONAL or REGIONAL."
  }
}

variable "backup_start_time" {
  description = "HH:MM time for daily backup window (UTC)"
  type        = string
  default     = "03:00"

  validation {
    condition     = can(regex("^([01]\\d|2[0-3]):[0-5]\\d$", var.backup_start_time))
    error_message = "Backup start time must be in HH:MM format (00:00-23:59)."
  }
}
```

**modules/gke_cluster/variables.tf:**

```hcl
variable "release_channel" {
  description = "GKE release channel: UNSPECIFIED, RAPID, REGULAR, STABLE"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["UNSPECIFIED", "RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be UNSPECIFIED, RAPID, REGULAR, or STABLE."
  }
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the control plane's private endpoint (must be /28)"
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0)) && endswith(var.master_ipv4_cidr_block, "/28")
    error_message = "Master CIDR must be a valid /28 CIDR block."
  }
}

variable "logging_service" {
  description = "Logging service: logging.googleapis.com/kubernetes or none"
  type        = string
  default     = "logging.googleapis.com/kubernetes"

  validation {
    condition     = contains(["logging.googleapis.com/kubernetes", "none"], var.logging_service)
    error_message = "Logging service must be logging.googleapis.com/kubernetes or none."
  }
}

variable "monitoring_service" {
  description = "Monitoring service: monitoring.googleapis.com/kubernetes or none"
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"

  validation {
    condition     = contains(["monitoring.googleapis.com/kubernetes", "none"], var.monitoring_service)
    error_message = "Monitoring service must be monitoring.googleapis.com/kubernetes or none."
  }
}

variable "maintenance_window_start_time" {
  description = "Daily maintenance window start time in UTC (HH:MM format)"
  type        = string
  default     = "02:00"

  validation {
    condition     = can(regex("^([01]\\d|2[0-3]):[0-5]\\d$", var.maintenance_window_start_time))
    error_message = "Maintenance window start time must be in HH:MM format."
  }
}
```

**modules/gke_node_pool/variables.tf:**

```hcl
variable "disk_type" {
  description = "Boot disk type: pd-standard, pd-ssd, pd-balanced"
  type        = string
  default     = "pd-standard"

  validation {
    condition     = contains(["pd-standard", "pd-ssd", "pd-balanced"], var.disk_type)
    error_message = "Disk type must be pd-standard, pd-ssd, or pd-balanced."
  }
}
```

**modules/subnet/variables.tf:**

```hcl
variable "purpose" {
  description = "Subnet purpose: PRIVATE or REGIONAL_MANAGED_PROXY"
  type        = string
  default     = "PRIVATE"

  validation {
    condition     = contains(["PRIVATE", "REGIONAL_MANAGED_PROXY"], var.purpose)
    error_message = "Purpose must be PRIVATE or REGIONAL_MANAGED_PROXY."
  }
}
```

**modules/naming/variables.tf:**

```hcl
variable "environment" {
  description = "Environment (e.g. dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

**Step 2: Run validation**

```bash
terraform -chdir=gob/networking validate
terraform -chdir=gob/database validate
terraform -chdir=gob/compute validate
terraform -chdir=gob/automation validate
```

**Step 3: Commit**

```bash
git add modules/
git commit -m "feat(modules): add validation blocks to all constrained variables"
```

---

## Task 8: Add `precondition` and `postcondition` checks

**Files:**
- Modify: `modules/gke_cluster/main.tf`
- Modify: `modules/cloud_sql/main.tf`
- Modify: `modules/vpc/main.tf`

**Step 1: Add postcondition to VPC**

In `modules/vpc/main.tf`, add lifecycle block to the resource:

```hcl
resource "google_compute_network" "this" {
  name                    = var.name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  lifecycle {
    postcondition {
      condition     = !self.auto_create_subnetworks
      error_message = "VPC must not auto-create subnetworks. Use explicit subnet modules."
    }
  }
}
```

**Step 2: Add precondition to GKE cluster**

In `modules/gke_cluster/main.tf`, add lifecycle block:

```hcl
  lifecycle {
    precondition {
      condition     = var.pods_secondary_range_name != "" && var.services_secondary_range_name != ""
      error_message = "GKE cluster requires both pods and services secondary range names for VPC-native networking."
    }
  }
```

**Step 3: Add postcondition to Cloud SQL**

In `modules/cloud_sql/main.tf`, add lifecycle block to the instance resource:

```hcl
  lifecycle {
    postcondition {
      condition     = !self.settings[0].ip_configuration[0].ipv4_enabled
      error_message = "Cloud SQL must not have a public IP. Use private networking only."
    }
  }
```

**Step 4: Run validation**

```bash
terraform -chdir=gob/networking validate
terraform -chdir=gob/database validate
terraform -chdir=gob/compute validate
```

**Step 5: Commit**

```bash
git add modules/vpc/main.tf modules/gke_cluster/main.tf modules/cloud_sql/main.tf
git commit -m "feat(modules): add precondition and postcondition checks for defense-in-depth"
```

---

## Task 9: Add `lifecycle` rules for critical resources

**Files:**
- Modify: `modules/cloud_sql/main.tf`
- Modify: `modules/cloud_sql/variables.tf`
- Modify: `modules/vpc/main.tf`
- Modify: `modules/vpc/variables.tf`

**Step 1: Add prevent_destroy variable to Cloud SQL**

In `modules/cloud_sql/variables.tf`:

```hcl
variable "prevent_destroy" {
  description = "Terraform-level protection against accidental resource deletion (separate from GCP deletion_protection)"
  type        = bool
  default     = true
}
```

**Note:** Terraform `prevent_destroy` cannot use variables in lifecycle blocks — it must be a literal. Instead, document the pattern via comments and rely on `deletion_protection` (which is already variable-driven). Remove this task step and use comments instead.

Actually, since `prevent_destroy` must be a literal boolean in lifecycle blocks (Terraform limitation), we will add it as `prevent_destroy = false` with a comment explaining that production should be `true` and requires manual code change.

In `modules/cloud_sql/main.tf`, merge with existing lifecycle block (from Task 8):

```hcl
  lifecycle {
    # Set to true for production — prevents terraform destroy from deleting the instance
    # This is a code-level safeguard in addition to GCP's deletion_protection flag
    prevent_destroy = false

    postcondition {
      condition     = !self.settings[0].ip_configuration[0].ipv4_enabled
      error_message = "Cloud SQL must not have a public IP. Use private networking only."
    }
  }
```

**Step 2: Same pattern for VPC**

In `modules/vpc/main.tf`, merge with existing lifecycle block:

```hcl
  lifecycle {
    # Set to true for production — prevents accidental VPC deletion (cascading subnet/firewall loss)
    prevent_destroy = false

    postcondition {
      condition     = !self.auto_create_subnetworks
      error_message = "VPC must not auto-create subnetworks. Use explicit subnet modules."
    }
  }
```

**Step 3: Run validation**

```bash
terraform -chdir=gob/networking validate
terraform -chdir=gob/database validate
```

**Step 4: Commit**

```bash
git add modules/cloud_sql/main.tf modules/vpc/main.tf
git commit -m "feat(modules): add lifecycle prevent_destroy scaffolding for VPC and Cloud SQL"
```

---

## Task 10: Add Terraform test files

**Files:**
- Create: `modules/naming/naming.tftest.hcl`
- Create: `modules/firewall_rule/firewall_rule.tftest.hcl`
- Create: `modules/static_ip/static_ip.tftest.hcl`

**Note:** We test modules that can be validated without real GCP resources (using `plan` command mode) and the naming module (using `apply` command mode since it's purely local).

**Step 1: Create modules/naming/naming.tftest.hcl**

```hcl
run "standard_naming" {
  command = plan

  variables {
    client_name  = "acme"
    product_name = "web"
    environment  = "dev"
    region       = "europe-west1"
    layer        = "networking"
  }

  assert {
    condition     = output.prefix == "acme-web-dev-euw1"
    error_message = "Naming prefix should be acme-web-dev-euw1, got ${output.prefix}"
  }

  assert {
    condition     = output.region_short == "euw1"
    error_message = "Region short should be euw1, got ${output.region_short}"
  }

  assert {
    condition     = output.common_labels["client"] == "acme"
    error_message = "Label client should be acme"
  }

  assert {
    condition     = output.common_labels["managed_by"] == "terraform"
    error_message = "Label managed_by should be terraform"
  }
}

run "us_region_naming" {
  command = plan

  variables {
    client_name  = "orel"
    product_name = "gob"
    environment  = "prod"
    region       = "us-central1"
    layer        = "compute"
  }

  assert {
    condition     = output.prefix == "orel-gob-prod-usc1"
    error_message = "Naming prefix should be orel-gob-prod-usc1, got ${output.prefix}"
  }
}

run "unknown_region_fallback" {
  command = plan

  variables {
    client_name  = "test"
    product_name = "app"
    environment  = "dev"
    region       = "southamerica-east1"
    layer        = "networking"
  }

  assert {
    condition     = output.region_short == "southamericaeast1"
    error_message = "Unknown region should fallback to dashes-removed format"
  }
}
```

**Step 2: Create modules/firewall_rule/firewall_rule.tftest.hcl**

```hcl
run "invalid_direction" {
  command = plan

  variables {
    name       = "test-fw"
    project_id = "test-project"
    network_id = "projects/test/global/networks/test"
    direction  = "INVALID"
    action     = "allow"
    protocol   = "tcp"
  }

  expect_failures = [var.direction]
}

run "invalid_action" {
  command = plan

  variables {
    name       = "test-fw"
    project_id = "test-project"
    network_id = "projects/test/global/networks/test"
    direction  = "INGRESS"
    action     = "permit"
    protocol   = "tcp"
  }

  expect_failures = [var.action]
}

run "invalid_protocol" {
  command = plan

  variables {
    name       = "test-fw"
    project_id = "test-project"
    network_id = "projects/test/global/networks/test"
    direction  = "INGRESS"
    action     = "allow"
    protocol   = "http"
  }

  expect_failures = [var.protocol]
}

run "invalid_priority" {
  command = plan

  variables {
    name       = "test-fw"
    project_id = "test-project"
    network_id = "projects/test/global/networks/test"
    direction  = "INGRESS"
    action     = "allow"
    protocol   = "tcp"
    priority   = 70000
  }

  expect_failures = [var.priority]
}
```

**Step 3: Create modules/static_ip/static_ip.tftest.hcl**

```hcl
run "invalid_address_type" {
  command = plan

  variables {
    name         = "test-ip"
    project_id   = "test-project"
    region       = "europe-west1"
    address_type = "PUBLIC"
  }

  expect_failures = [var.address_type]
}

run "invalid_network_tier" {
  command = plan

  variables {
    name         = "test-ip"
    project_id   = "test-project"
    region       = "europe-west1"
    network_tier = "BASIC"
  }

  expect_failures = [var.network_tier]
}
```

**Step 4: Run tests**

```bash
terraform -chdir=modules/naming test
terraform -chdir=modules/firewall_rule test
terraform -chdir=modules/static_ip test
```

Expected: All tests pass.

**Step 5: Commit**

```bash
git add modules/naming/naming.tftest.hcl modules/firewall_rule/firewall_rule.tftest.hcl modules/static_ip/static_ip.tftest.hcl
git commit -m "feat(tests): add Terraform native tests for naming, firewall_rule, and static_ip modules"
```

---

## Task 11: Add explanatory comments to dev.tfvars

**Files:**
- Modify: `gob/compute/tfvars/orel/dev.tfvars`
- Modify: `gob/automation/tfvars/orel/dev.tfvars`
- Modify: `gob/database/tfvars/orel/dev.tfvars`

**Step 1: Add comments to compute dev.tfvars**

Add comment above `master_authorized_networks`:

```hcl
      # DEV ONLY: Open to all IPs for ephemeral development environment.
      # For staging/prod: restrict to office IPs, VPN ranges, and CI/CD runner IPs.
      master_authorized_networks = {
```

**Step 2: Add comments to automation dev.tfvars**

Add comment above the roles list:

```hcl
      # Least-privilege roles for CI/CD pipeline operations.
      # Each role scoped to what terraform apply/destroy needs.
      roles = [
```

**Step 3: Add comments to database dev.tfvars**

Add comment above `deletion_protection`:

```hcl
        # DEV ONLY: Disabled for easy teardown of ephemeral environment.
        # For staging/prod: set to true to prevent accidental data loss.
        deletion_protection = false
```

**Step 4: Commit**

```bash
git add gob/compute/tfvars/ gob/automation/tfvars/ gob/database/tfvars/
git commit -m "docs(tfvars): add explanatory comments for security-relevant dev overrides"
```

---

## Task 12: Create staging/prod tfvars templates

**Files:**
- Create: `gob/networking/tfvars/orel/staging.tfvars.example`
- Create: `gob/networking/tfvars/orel/prod.tfvars.example`

**Step 1: Create staging.tfvars.example**

```hcl
# Staging environment — mirrors prod with smaller resources
# Usage: terraform -chdir=gob/networking plan -var-file=tfvars/orel/staging.tfvars

client_name  = "orel"
product_name = "gob"
environment  = "staging"
project_id   = "orel-bh-sandbox"  # Use separate project for staging in production
region       = "europe-west1"

apis = ["compute.googleapis.com", "container.googleapis.com", "servicenetworking.googleapis.com", "sqladmin.googleapis.com"]

vpcs = {
  "main" = {}
}

subnets = {
  "gke" = {
    vpc_key               = "main"
    cidr                  = "10.32.0.0/20"
    purpose               = "PRIVATE"
    private_google_access = true
    secondary_ranges = {
      "pods"     = { cidr = "10.36.0.0/14" }
      "services" = { cidr = "10.40.0.0/20" }
    }
  }
  "proxy" = {
    vpc_key = "main"
    cidr    = "10.32.16.0/23"
    purpose = "REGIONAL_MANAGED_PROXY"
    role    = "ACTIVE"
  }
}

firewall_rules = {
  "deny-all-ingress" = {
    vpc_key       = "main"
    direction     = "INGRESS"
    priority      = 65534
    action        = "deny"
    protocol      = "all"
    source_ranges = ["0.0.0.0/0"]
  }
  "allow-iap-ssh" = {
    vpc_key       = "main"
    direction     = "INGRESS"
    priority      = 1000
    action        = "allow"
    protocol      = "tcp"
    ports         = ["22"]
    source_ranges = ["35.235.240.0/20"]
  }
  "allow-health-checks" = {
    vpc_key       = "main"
    direction     = "INGRESS"
    priority      = 1000
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
    target_tags   = ["gke-node"]
  }
  "allow-proxy-to-backends" = {
    vpc_key       = "main"
    direction     = "INGRESS"
    priority      = 1000
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["10.32.16.0/23"]
    target_tags   = ["gke-node"]
  }
}

cloud_nats = {
  "main" = {
    vpc_key = "main"
  }
}

psa_connections = {
  "google-managed" = {
    vpc_key = "main"
    cidr    = "10.48.0.0/16"
  }
}

static_ips = {
  "ingress" = {
    address_type = "EXTERNAL"
    network_tier = "STANDARD"
  }
}
```

**Step 2: Create prod.tfvars.example**

```hcl
# Production environment — full redundancy, strict security
# Usage: terraform -chdir=gob/networking plan -var-file=tfvars/orel/prod.tfvars
#
# IMPORTANT differences from dev:
# - Separate GCP project (recommended)
# - Non-overlapping CIDR ranges
# - PREMIUM network tier for global load balancing
# - No 0.0.0.0/0 in master_authorized_networks (compute layer)
# - deletion_protection = true on all stateful resources (database layer)
# - backup_enabled = true on Cloud SQL (database layer)

client_name  = "orel"
product_name = "gob"
environment  = "prod"
project_id   = "orel-bh-production"  # Separate project for production
region       = "europe-west1"

apis = ["compute.googleapis.com", "container.googleapis.com", "servicenetworking.googleapis.com", "sqladmin.googleapis.com"]

vpcs = {
  "main" = {}
}

subnets = {
  "gke" = {
    vpc_key               = "main"
    cidr                  = "10.64.0.0/20"
    purpose               = "PRIVATE"
    private_google_access = true
    secondary_ranges = {
      "pods"     = { cidr = "10.68.0.0/14" }
      "services" = { cidr = "10.72.0.0/20" }
    }
  }
  "proxy" = {
    vpc_key = "main"
    cidr    = "10.64.16.0/23"
    purpose = "REGIONAL_MANAGED_PROXY"
    role    = "ACTIVE"
  }
}

firewall_rules = {
  "deny-all-ingress" = {
    vpc_key       = "main"
    direction     = "INGRESS"
    priority      = 65534
    action        = "deny"
    protocol      = "all"
    source_ranges = ["0.0.0.0/0"]
  }
  "allow-iap-ssh" = {
    vpc_key       = "main"
    direction     = "INGRESS"
    priority      = 1000
    action        = "allow"
    protocol      = "tcp"
    ports         = ["22"]
    source_ranges = ["35.235.240.0/20"]
  }
  "allow-health-checks" = {
    vpc_key       = "main"
    direction     = "INGRESS"
    priority      = 1000
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
    target_tags   = ["gke-node"]
  }
  "allow-proxy-to-backends" = {
    vpc_key       = "main"
    direction     = "INGRESS"
    priority      = 1000
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["10.64.16.0/23"]
    target_tags   = ["gke-node"]
  }
}

cloud_nats = {
  "main" = {
    vpc_key = "main"
  }
}

psa_connections = {
  "google-managed" = {
    vpc_key = "main"
    cidr    = "10.80.0.0/16"
  }
}

static_ips = {
  "ingress" = {
    address_type = "EXTERNAL"
    network_tier = "PREMIUM"  # PREMIUM for production — global load balancing support
  }
}
```

**Step 3: Commit**

```bash
git add gob/networking/tfvars/
git commit -m "docs(tfvars): add staging and prod tfvars examples for networking layer"
```

---

## Task 13: Create module track decision framework

**Files:**
- Create: `docs/plans/2026-03-14-module-decision-framework.md`

**Step 1: Write the framework document**

```markdown
# Module Track Decision Framework

## Purpose

This framework helps determine which Terraform module strategy to use
at the start of a new GCP project. The decision affects maintainability,
compliance, and delivery speed.

## Three Tracks

### Track A: Custom Per-Resource Modules
- Each module wraps exactly one GCP resource
- Maximum control and transparency
- Team learns GCP internals deeply
- Best for: teams with GCP expertise, unique architectures, learning engagements

### Track B: Official Google Terraform Modules
- Community-maintained, Google-backed
- Pre-built best practices (labels, logging, security)
- Faster time-to-market
- Best for: enterprise compliance requirements, small teams, standard architectures

### Track C: Hybrid
- Official modules for complex resources (VPC, GKE, Cloud SQL)
- Custom modules for simple/unique resources (WIF, project APIs)
- Best for: most production projects at Sela

## Decision Criteria

| Factor | Custom (A) | Official (B) | Hybrid (C) |
|--------|-----------|-------------|-----------|
| Team GCP experience | Deep | Any | Moderate+ |
| Compliance requirements | Flexible | Strict (auditors want "official") | Standard |
| Timeline | Longer | Fastest | Medium |
| Customization needs | High | Low-Medium | Medium |
| Long-term maintenance | Team owns | Community owns | Shared |
| Team size | 3+ DevOps | 1-2 DevOps | 2+ DevOps |

## Decision Flow

1. Does the client require "Google-approved" modules for compliance? → Track B
2. Does the project have highly custom architecture? → Track A
3. Is the team small (<3) AND timeline tight? → Track B
4. Default → Track C (Hybrid)
```

**Step 2: Commit**

```bash
git add docs/plans/2026-03-14-module-decision-framework.md
git commit -m "docs(plans): add module track decision framework for client projects"
```

---

## Task 14: Update STATUS.md and CLAUDE.md

**Files:**
- Modify: `docs/STATUS.md`

**Step 1: Add Gold Standard section to STATUS.md**

Add after Stage 7 in the roadmap:

```markdown
8. **Gold Standard Hardening** — IN PROGRESS (feat/gold-standard-hardening branch)
   - Labels, IAM hardening, GKE security, validation, testing, DRY
   - Design doc: `docs/plans/2026-03-14-gold-standard-hardening-design.md`
```

**Step 2: Commit**

```bash
git add docs/STATUS.md
git commit -m "docs(status): add Gold Standard hardening stage to roadmap"
```

---

## Verification Checklist

After all tasks complete:
- [ ] `terraform validate` passes on all 4 layers
- [ ] `terraform test` passes on naming, firewall_rule, static_ip modules
- [ ] All 13 modules have `terraform {}` blocks
- [ ] Validation blocks on all constrained variables
- [ ] Labels passed to all supporting resources
- [ ] No `roles/editor` in IAM bindings
- [ ] GKE has network policy, shielded nodes, logging, monitoring, maintenance window
- [ ] Sensitive outputs marked
- [ ] DRY — single naming module, no duplicated locals
- [ ] dev.tfvars has explanatory comments
- [ ] staging/prod tfvars examples exist
- [ ] Module decision framework documented
