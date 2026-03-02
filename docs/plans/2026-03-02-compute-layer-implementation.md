# Compute Layer (Stage 3) - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the Compute Layer — GKE Standard (Zonal) with Private Nodes, Spot-based Node Pool, and Workload Identity enabled, following the per-resource module + layer orchestration pattern.

**Architecture:** Two new per-resource modules (`gke_cluster` wrapping `google_container_cluster`, `gke_node_pool` wrapping `google_container_node_pool`). A new `gob/compute/` layer orchestrates them with `for_each`, reads networking outputs via `terraform_remote_state`, and uses the same 8-file manifest + tfvars pattern.

**Tech Stack:** Terraform >= 1.6, Google Provider >= 6.0, GCS backend (`terraform-states-gcs`), GKE Standard (Zonal), Spot Instances, Workload Identity.

---

## Task 1: Create `modules/gke_cluster` module

Per-resource module wrapping `google_container_cluster`.

**Files:**
- Create: `modules/gke_cluster/main.tf`
- Create: `modules/gke_cluster/variables.tf`
- Create: `modules/gke_cluster/outputs.tf`

**Step 1: Create `modules/gke_cluster/variables.tf`**

```hcl
variable "name" {
  description = "Full name for the GKE cluster (pre-computed by caller)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "GKE location — a zone for zonal clusters (e.g. europe-west1-b) or a region for regional clusters"
  type        = string
}

variable "network_id" {
  description = "VPC network self_link"
  type        = string
}

variable "subnet_id" {
  description = "Subnet self_link for the GKE nodes"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Name of the subnet secondary range for Pod IPs (VPC-native)"
  type        = string
}

variable "services_secondary_range_name" {
  description = "Name of the subnet secondary range for Service IPs (VPC-native)"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the control plane's private endpoint (must be /28, must not overlap with any subnet)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "Map of CIDR blocks authorized to access the Kubernetes API. Key = descriptive name, value = { cidr_block }."
  type = map(object({
    cidr_block = string
  }))
  default = {}
}

variable "release_channel" {
  description = "GKE release channel: UNSPECIFIED, RAPID, REGULAR, STABLE"
  type        = string
  default     = "REGULAR"
}

variable "workload_identity_enabled" {
  description = "Enable Workload Identity (recommended for secure Pod-to-GCP-service authentication)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion. Set to false for ephemeral environments."
  type        = bool
  default     = false
}
```

**Step 2: Create `modules/gke_cluster/main.tf`**

```hcl
resource "google_container_cluster" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location

  network    = var.network_id
  subnetwork = var.subnet_id

  # Remove the default node pool — we manage node pools as separate resources
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.deletion_protection

  # VPC-native networking using subnet secondary ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  # Private cluster: nodes get private IPs only, control plane endpoint stays public
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Master Authorized Networks — dynamic block, varies per client/environment
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          display_name = cidr_blocks.key
          cidr_block   = cidr_blocks.value.cidr_block
        }
      }
    }
  }

  # Workload Identity — enables secure KSA-to-GSA binding (configured in Stage 4)
  dynamic "workload_identity_config" {
    for_each = var.workload_identity_enabled ? [1] : []
    content {
      workload_pool = "${var.project_id}.svc.id.goog"
    }
  }

  # Release channel controls automatic version upgrades
  release_channel {
    channel = var.release_channel
  }
}
```

**Step 3: Create `modules/gke_cluster/outputs.tf`**

```hcl
output "id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.this.id
}

output "name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "endpoint" {
  description = "GKE cluster API endpoint"
  value       = google_container_cluster.this.endpoint
}

output "ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster"
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "master_version" {
  description = "Current master version of the cluster"
  value       = google_container_cluster.this.master_version
}
```

**Step 4: Commit**

```bash
git add modules/gke_cluster/
git commit -m "feat(compute): add gke_cluster per-resource module"
```

---

## Task 2: Create `modules/gke_node_pool` module

Per-resource module wrapping `google_container_node_pool`.

**Files:**
- Create: `modules/gke_node_pool/main.tf`
- Create: `modules/gke_node_pool/variables.tf`
- Create: `modules/gke_node_pool/outputs.tf`

**Step 1: Create `modules/gke_node_pool/variables.tf`**

```hcl
variable "name" {
  description = "Full name for the node pool (pre-computed by caller)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "GKE location — must match the cluster's location"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster this pool belongs to"
  type        = string
}

variable "machine_type" {
  description = "GCE machine type for the nodes"
  type        = string
  default     = "e2-medium"
}

variable "spot" {
  description = "Use Spot VMs (preemptible replacement, up to 90% cheaper)"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 3
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "disk_type" {
  description = "Boot disk type: pd-standard, pd-ssd, pd-balanced"
  type        = string
  default     = "pd-standard"
}

variable "auto_repair" {
  description = "Enable auto-repair for failed/unhealthy nodes"
  type        = bool
  default     = true
}

variable "auto_upgrade" {
  description = "Enable automatic node version upgrades"
  type        = bool
  default     = true
}

variable "oauth_scopes" {
  description = "OAuth scopes for node service account"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}
```

**Step 2: Create `modules/gke_node_pool/main.tf`**

```hcl
resource "google_container_node_pool" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location
  cluster  = var.cluster_name

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = var.auto_repair
    auto_upgrade = var.auto_upgrade
  }

  node_config {
    machine_type = var.machine_type
    spot         = var.spot
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    oauth_scopes = var.oauth_scopes

    # Required for Workload Identity on nodes — tells kubelet to use GKE metadata server
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
```

**Step 3: Create `modules/gke_node_pool/outputs.tf`**

```hcl
output "id" {
  description = "Node pool ID"
  value       = google_container_node_pool.this.id
}

output "name" {
  description = "Node pool name"
  value       = google_container_node_pool.this.name
}
```

**Step 4: Commit**

```bash
git add modules/gke_node_pool/
git commit -m "feat(compute): add gke_node_pool per-resource module"
```

---

## Task 3: Create `gob/compute/` layer — scaffold files

Create the 8 boilerplate files (identical to other layers), plus tfvars directory.

**Files:**
- Create: `gob/compute/versions.tf`
- Create: `gob/compute/backend.tf`
- Create: `gob/compute/providers.tf`
- Create: `gob/compute/locals.tf`
- Create: `gob/compute/data.tf`
- Create: `gob/compute/variables.tf`
- Create: `gob/compute/outputs.tf`
- Create: `gob/compute/main.tf`
- Create: `gob/compute/tfvars/orel/dev.tfvars`

**Step 1: Create `gob/compute/versions.tf`** (identical to database layer)

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

**Step 2: Create `gob/compute/backend.tf`** (identical to database layer)

```hcl
terraform {
  backend "gcs" {
    bucket = "terraform-states-gcs"
    # prefix is set dynamically via: terraform init -backend-config="prefix=CLIENT/ENV/LAYER"
  }
}
```

**Step 3: Create `gob/compute/providers.tf`** (identical to database layer)

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}
```

**Step 4: Create `gob/compute/locals.tf`** (identical to database layer)

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

**Step 5: Create `gob/compute/data.tf`**

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

**Step 6: Create `gob/compute/variables.tf`**

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
# GKE Clusters
# =============================================================================

variable "gke_clusters" {
  description = "Map of GKE cluster configurations. Key = cluster name suffix."
  type = map(object({
    vpc_key                       = optional(string, "main")
    subnet_key                    = string
    pods_secondary_range_key      = optional(string, "pods")
    services_secondary_range_key  = optional(string, "services")
    zone                          = string
    master_ipv4_cidr_block        = optional(string, "172.16.0.0/28")
    release_channel               = optional(string, "REGULAR")
    workload_identity_enabled     = optional(bool, true)
    deletion_protection           = optional(bool, false)
    master_authorized_networks    = optional(map(object({
      cidr_block = string
    })), {})
  }))
  default = {}
}

# =============================================================================
# Node Pools
# =============================================================================

variable "node_pools" {
  description = "Map of GKE node pool configurations. Key = pool name suffix."
  type = map(object({
    cluster_key    = string
    machine_type   = optional(string, "e2-medium")
    spot           = optional(bool, true)
    min_node_count = optional(number, 1)
    max_node_count = optional(number, 3)
    disk_size_gb   = optional(number, 50)
    disk_type      = optional(string, "pd-standard")
    auto_repair    = optional(bool, true)
    auto_upgrade   = optional(bool, true)
    oauth_scopes   = optional(list(string), ["https://www.googleapis.com/auth/cloud-platform"])
  }))
  default = {}
}
```

**Step 7: Create `gob/compute/main.tf`**

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
# GKE Clusters
# =============================================================================

module "gke_clusters" {
  for_each = var.gke_clusters
  source   = "../../modules/gke_cluster"

  name       = "${local.naming_prefix}-gke-${each.key}"
  project_id = var.project_id
  location   = each.value.zone

  network_id                    = data.terraform_remote_state.networking.outputs.vpc_self_links[each.value.vpc_key]
  subnet_id                     = data.terraform_remote_state.networking.outputs.subnet_self_links[each.value.subnet_key]
  pods_secondary_range_name     = data.terraform_remote_state.networking.outputs.subnet_secondary_range_names[each.value.subnet_key][each.value.pods_secondary_range_key]
  services_secondary_range_name = data.terraform_remote_state.networking.outputs.subnet_secondary_range_names[each.value.subnet_key][each.value.services_secondary_range_key]

  master_ipv4_cidr_block     = each.value.master_ipv4_cidr_block
  release_channel            = each.value.release_channel
  workload_identity_enabled  = each.value.workload_identity_enabled
  deletion_protection        = each.value.deletion_protection
  master_authorized_networks = each.value.master_authorized_networks

  depends_on = [module.apis]
}

# =============================================================================
# Node Pools
# =============================================================================

module "node_pools" {
  for_each = var.node_pools
  source   = "../../modules/gke_node_pool"

  name         = "${local.naming_prefix}-gke-${each.value.cluster_key}-${each.key}"
  project_id   = var.project_id
  location     = var.gke_clusters[each.value.cluster_key].zone
  cluster_name = module.gke_clusters[each.value.cluster_key].name

  machine_type   = each.value.machine_type
  spot           = each.value.spot
  min_node_count = each.value.min_node_count
  max_node_count = each.value.max_node_count
  disk_size_gb   = each.value.disk_size_gb
  disk_type      = each.value.disk_type
  auto_repair    = each.value.auto_repair
  auto_upgrade   = each.value.auto_upgrade
  oauth_scopes   = each.value.oauth_scopes
}
```

**Step 8: Create `gob/compute/outputs.tf`**

```hcl
# --- GKE Clusters ---

output "cluster_ids" {
  description = "Map of cluster key => cluster ID"
  value       = { for k, v in module.gke_clusters : k => v.id }
}

output "cluster_names" {
  description = "Map of cluster key => cluster name"
  value       = { for k, v in module.gke_clusters : k => v.name }
}

output "cluster_endpoints" {
  description = "Map of cluster key => API endpoint"
  value       = { for k, v in module.gke_clusters : k => v.endpoint }
}

output "cluster_ca_certificates" {
  description = "Map of cluster key => base64-encoded CA certificate"
  value       = { for k, v in module.gke_clusters : k => v.ca_certificate }
  sensitive   = true
}

output "cluster_master_versions" {
  description = "Map of cluster key => master version"
  value       = { for k, v in module.gke_clusters : k => v.master_version }
}

# --- Node Pools ---

output "node_pool_ids" {
  description = "Map of node pool key => node pool ID"
  value       = { for k, v in module.node_pools : k => v.id }
}

output "node_pool_names" {
  description = "Map of node pool key => node pool name"
  value       = { for k, v in module.node_pools : k => v.name }
}

# --- Naming ---

output "naming_prefix" {
  description = "The computed naming prefix for this environment"
  value       = local.naming_prefix
}
```

**Step 9: Create `gob/compute/tfvars/orel/dev.tfvars`**

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
  "container.googleapis.com",
]

# =============================================================================
# GKE Clusters
# =============================================================================

gke_clusters = {
  "main" = {
    subnet_key             = "gke"
    zone                   = "europe-west1-b"
    master_ipv4_cidr_block = "172.16.0.0/28"
    release_channel        = "REGULAR"
    master_authorized_networks = {
      "allow-all" = {
        cidr_block = "0.0.0.0/0"
      }
    }
  }
}

# =============================================================================
# Node Pools
# =============================================================================

node_pools = {
  "spot" = {
    cluster_key    = "main"
    machine_type   = "e2-medium"
    spot           = true
    min_node_count = 1
    max_node_count = 3
    disk_size_gb   = 50
  }
}
```

**Step 10: Commit**

```bash
git add gob/compute/
git commit -m "feat(compute): add Stage 3 compute layer with GKE Standard"
```

---

## Task 4: Validate the Terraform configuration

Run `terraform validate` to ensure all modules and references are correct.

**Step 1: Initialize the compute layer**

```bash
terraform -chdir=gob/compute init -backend-config="prefix=orel/dev/compute"
```

Expected: successful initialization, provider downloaded.

**Step 2: Validate**

```bash
terraform -chdir=gob/compute validate
```

Expected: `Success! The configuration is valid.`

**Step 3: Fix any validation errors**

If validation fails, fix the errors and re-validate until it passes.

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix(compute): fix validation errors"
```

---

## Task 5: Update CLAUDE.md with Stage 3 status

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update directory structure** — add `gke_cluster/` and `gke_node_pool/` under `modules/`

**Step 2: Update "Current Status"** — add Stage 3 section with resource table and verification checklist

**Step 3: Update "How to Run"** — add compute layer commands

**Step 4: Update Stage 3 roadmap** — mark as "CODE READY, NOT APPLIED"

**Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with Stage 3 compute layer status"
```
