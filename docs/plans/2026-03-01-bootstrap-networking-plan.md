# Stage 1: Bootstrap & Networking Implementation Plan

> **STATUS: SUPERSEDED** - This plan was for the v1 monolithic module architecture.
> The project was refactored to per-resource modules. See design-v2.md for current architecture.

**Goal:** Create the networking foundation (VPC, subnets, NAT, firewall, PSA) as a reusable Terraform module with layer-based state isolation.

**Architecture:** Flat networking module with all resources in a single `main.tf`, driven by `map(object)` variables via `for_each`. Client environment (`clients/orel-sandbox/dev/1-networking/`) consumes the module and passes configuration through a single `.auto.tfvars` file. State stored in GCS with per-layer isolation.

**Tech Stack:** Terraform >= 1.6, Google Provider >= 6.x, GCS backend

**Design doc:** `docs/plans/2026-03-01-bootstrap-networking-design.md`

---

## Task 1: Create Directory Structure

**Files:**
- Create: `modules/networking/` directory
- Create: `clients/orel-sandbox/dev/1-networking/` directory

**Step 1: Create all directories**

```bash
mkdir -p modules/networking
mkdir -p clients/orel-sandbox/dev/1-networking
```

**Step 2: Commit empty structure**

```bash
# Create .gitkeep files so git tracks empty dirs
touch modules/networking/.gitkeep
touch clients/orel-sandbox/dev/1-networking/.gitkeep
git add modules/ clients/
git commit -m "scaffold: create directory structure for networking module and client environment"
```

---

## Task 2: Networking Module - variables.tf

**Files:**
- Create: `modules/networking/variables.tf`

**Step 1: Write the module variable declarations**

All 6 input variables with full type definitions. These are the "contracts" that any client environment must satisfy.

```hcl
# modules/networking/variables.tf

# --- Project & Region ---

variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "The GCP region for all regional resources"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

# --- APIs ---

variable "apis" {
  description = "List of GCP APIs to enable in the project"
  type        = list(string)
  default     = []
}

# --- Subnets ---

variable "subnets" {
  description = <<-EOT
    Map of subnets to create in the VPC.
    Key = subnet name suffix (will be prefixed with vpc_name).

    Fields:
    - cidr: The primary IP CIDR range for the subnet
    - purpose: PRIVATE (default) or REGIONAL_MANAGED_PROXY (for ALB)
    - role: Set to ACTIVE for proxy-only subnets, null otherwise
    - private_google_access: Enable Private Google Access (default: true)
    - secondary_ranges: Map of secondary ranges (for GKE pods/services)
  EOT

  type = map(object({
    cidr                  = string
    purpose               = optional(string, "PRIVATE")
    role                  = optional(string, null)
    private_google_access = optional(bool, true)
    secondary_ranges = optional(map(object({
      cidr = string
    })), {})
  }))
}

# --- Firewall ---

variable "firewall_rules" {
  description = <<-EOT
    Map of firewall rules to create in the VPC.
    Key = rule name suffix (will be prefixed with vpc_name).

    Fields:
    - direction: INGRESS (default) or EGRESS
    - priority: Rule priority (lower = higher priority). Default: 1000
    - action: "allow" or "deny"
    - protocol: Protocol (tcp, udp, icmp, all)
    - ports: List of port ranges (e.g., ["80", "443", "8080-8090"])
    - source_ranges: Source CIDR ranges (for INGRESS)
    - destination_ranges: Destination CIDR ranges (for EGRESS)
    - target_tags: Network tags to apply rule to
    - source_tags: Source network tags (for INGRESS)
  EOT

  type = map(object({
    direction          = optional(string, "INGRESS")
    priority           = optional(number, 1000)
    action             = string
    protocol           = string
    ports              = optional(list(string), [])
    source_ranges      = optional(list(string), [])
    destination_ranges = optional(list(string), [])
    target_tags        = optional(list(string), [])
    source_tags        = optional(list(string), [])
  }))
  default = {}
}

# --- NAT ---

variable "nat_config" {
  description = <<-EOT
    Configuration for Cloud NAT.
    Set to null to skip NAT creation.

    Fields:
    - nat_ip_allocate_option: AUTO_ONLY (default) or MANUAL_ONLY
    - source_subnetwork_ip_ranges_to_nat: Which subnet ranges to NAT
    - min_ports_per_vm: Minimum ports per VM (default: 64)
    - max_ports_per_vm: Maximum ports per VM (default: 4096)
    - log_filter: Logging filter (default: ERRORS_ONLY)
  EOT

  type = object({
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    min_ports_per_vm                   = optional(number, 64)
    max_ports_per_vm                   = optional(number, 4096)
    log_filter                         = optional(string, "ERRORS_ONLY")
  })
  default = null
}

# --- PSA ---

variable "psa_ranges" {
  description = <<-EOT
    Map of Private Services Access IP ranges to allocate.
    Key = allocation name. These ranges are used by Google-managed
    services (Cloud SQL, Memorystore, etc.) via VPC peering.

    Fields:
    - cidr: The CIDR range to allocate for Google services
  EOT

  type = map(object({
    cidr = string
  }))
  default = {}
}
```

**Step 2: Validate syntax**

```bash
cd modules/networking
terraform fmt -check
```
Expected: No output (files are formatted).

**Step 3: Commit**

```bash
git add modules/networking/variables.tf
git commit -m "feat(networking): add module variable declarations with map(object) types"
```

---

## Task 3: Networking Module - locals.tf

**Files:**
- Create: `modules/networking/locals.tf`

**Step 1: Write locals for computed values**

Locals flatten the nested subnet secondary_ranges map for the `google_compute_subnetwork` dynamic blocks.

```hcl
# modules/networking/locals.tf

locals {
  # Filter subnets by purpose for targeted operations
  private_subnets = {
    for k, v in var.subnets : k => v if v.purpose == "PRIVATE"
  }

  # Extract the first subnet that has secondary ranges named "pods" and "services"
  # This is used to output GKE-specific range names for the compute layer
  gke_subnet = one([
    for k, v in var.subnets : {
      name                       = "${var.vpc_name}-${k}"
      pod_secondary_range_name   = "${var.vpc_name}-${k}-pods"
      svc_secondary_range_name   = "${var.vpc_name}-${k}-services"
    }
    if contains(keys(v.secondary_ranges), "pods") && contains(keys(v.secondary_ranges), "services")
  ])
}
```

**Step 2: Commit**

```bash
git add modules/networking/locals.tf
git commit -m "feat(networking): add locals for computed subnet values"
```

---

## Task 4: Networking Module - main.tf (All Resources)

**Files:**
- Create: `modules/networking/main.tf`

This is the core file. All resources in one file, each driven by its corresponding variable.

**Step 1: Write main.tf with all resources**

```hcl
# modules/networking/main.tf

# =============================================================================
# API Enablement
# =============================================================================

resource "google_project_service" "apis" {
  for_each = toset(var.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# =============================================================================
# VPC Network
# =============================================================================

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.apis]
}

# =============================================================================
# Subnets (for_each on var.subnets)
# =============================================================================

resource "google_compute_subnetwork" "subnets" {
  for_each = var.subnets

  name          = "${var.vpc_name}-${each.key}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = each.value.cidr
  purpose       = each.value.purpose
  role          = each.value.role

  private_ip_google_access = each.value.purpose == "PRIVATE" ? each.value.private_google_access : null

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges

    content {
      range_name    = "${var.vpc_name}-${each.key}-${secondary_ip_range.key}"
      ip_cidr_range = secondary_ip_range.value.cidr
    }
  }
}

# =============================================================================
# Firewall Rules (for_each on var.firewall_rules)
# =============================================================================

resource "google_compute_firewall" "rules" {
  for_each = var.firewall_rules

  name      = "${var.vpc_name}-${each.key}"
  project   = var.project_id
  network   = google_compute_network.vpc.id
  direction = each.value.direction
  priority  = each.value.priority

  source_ranges      = each.value.direction == "INGRESS" ? each.value.source_ranges : null
  destination_ranges = each.value.direction == "EGRESS" ? each.value.destination_ranges : null
  target_tags        = length(each.value.target_tags) > 0 ? each.value.target_tags : null
  source_tags        = each.value.direction == "INGRESS" && length(each.value.source_tags) > 0 ? each.value.source_tags : null

  dynamic "allow" {
    for_each = each.value.action == "allow" ? [1] : []

    content {
      protocol = each.value.protocol
      ports    = length(each.value.ports) > 0 ? each.value.ports : null
    }
  }

  dynamic "deny" {
    for_each = each.value.action == "deny" ? [1] : []

    content {
      protocol = each.value.protocol
      ports    = length(each.value.ports) > 0 ? each.value.ports : null
    }
  }
}

# =============================================================================
# Cloud Router + Cloud NAT
# =============================================================================

resource "google_compute_router" "router" {
  count = var.nat_config != null ? 1 : 0

  name    = "${var.vpc_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  count = var.nat_config != null ? 1 : 0

  name                               = "${var.vpc_name}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.router[0].name
  nat_ip_allocate_option             = var.nat_config.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = var.nat_config.source_subnetwork_ip_ranges_to_nat
  min_ports_per_vm                   = var.nat_config.min_ports_per_vm
  max_ports_per_vm                   = var.nat_config.max_ports_per_vm

  log_config {
    enable = true
    filter = var.nat_config.log_filter
  }
}

# =============================================================================
# Private Services Access (PSA)
# =============================================================================

resource "google_compute_global_address" "psa" {
  for_each = var.psa_ranges

  name          = "${var.vpc_name}-${each.key}"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = tonumber(split("/", each.value.cidr)[1])
  address       = split("/", each.value.cidr)[0]
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "psa" {
  count = length(var.psa_ranges) > 0 ? 1 : 0

  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [for k, v in google_compute_global_address.psa : v.name]

  depends_on = [google_project_service.apis]
}
```

**Step 2: Format**

```bash
cd modules/networking
terraform fmt
```

**Step 3: Commit**

```bash
git add modules/networking/main.tf
git commit -m "feat(networking): add all resources - VPC, subnets, firewall, NAT, PSA, APIs"
```

---

## Task 5: Networking Module - outputs.tf

**Files:**
- Create: `modules/networking/outputs.tf`

**Step 1: Write all module outputs**

```hcl
# modules/networking/outputs.tf

# --- VPC ---

output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_self_link" {
  description = "The self link of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

# --- Subnets ---

output "subnet_ids" {
  description = "Map of subnet name => subnet ID"
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.id }
}

output "subnet_self_links" {
  description = "Map of subnet name => subnet self link"
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}

output "subnet_cidrs" {
  description = "Map of subnet name => primary CIDR range"
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.ip_cidr_range }
}

# --- GKE-specific outputs ---

output "gke_subnet_name" {
  description = "The full name of the GKE subnet (for compute layer)"
  value       = local.gke_subnet != null ? local.gke_subnet.name : null
}

output "pod_secondary_range_name" {
  description = "The name of the secondary range for GKE pods"
  value       = local.gke_subnet != null ? local.gke_subnet.pod_secondary_range_name : null
}

output "service_secondary_range_name" {
  description = "The name of the secondary range for GKE services"
  value       = local.gke_subnet != null ? local.gke_subnet.svc_secondary_range_name : null
}

# --- PSA ---

output "psa_connection_id" {
  description = "The ID of the PSA connection (for Cloud SQL dependency)"
  value       = length(google_service_networking_connection.psa) > 0 ? google_service_networking_connection.psa[0].id : null
}

# --- NAT ---

output "router_id" {
  description = "The ID of the Cloud Router"
  value       = length(google_compute_router.router) > 0 ? google_compute_router.router[0].id : null
}

output "nat_id" {
  description = "The ID of the Cloud NAT"
  value       = length(google_compute_router_nat.nat) > 0 ? google_compute_router_nat.nat[0].id : null
}
```

**Step 2: Commit**

```bash
git add modules/networking/outputs.tf
git commit -m "feat(networking): add module outputs for cross-layer consumption"
```

---

## Task 6: Client Environment - versions.tf + providers.tf + backend.tf

**Files:**
- Create: `clients/orel-sandbox/dev/1-networking/versions.tf`
- Create: `clients/orel-sandbox/dev/1-networking/providers.tf`
- Create: `clients/orel-sandbox/dev/1-networking/backend.tf`

**Step 1: Write versions.tf**

```hcl
# clients/orel-sandbox/dev/1-networking/versions.tf

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

**Step 2: Write providers.tf**

```hcl
# clients/orel-sandbox/dev/1-networking/providers.tf

provider "google" {
  project = var.project_id
  region  = var.region
}
```

**Step 3: Write backend.tf**

```hcl
# clients/orel-sandbox/dev/1-networking/backend.tf

terraform {
  backend "gcs" {
    bucket = "terraform-states-gcs"
    prefix = "orel-sandbox/dev/networking"
  }
}
```

**Step 4: Commit**

```bash
git add clients/orel-sandbox/dev/1-networking/versions.tf \
        clients/orel-sandbox/dev/1-networking/providers.tf \
        clients/orel-sandbox/dev/1-networking/backend.tf
git commit -m "feat(sandbox/networking): add version constraints, provider config, and GCS backend"
```

---

## Task 7: Client Environment - variables.tf + locals.tf + data.tf

**Files:**
- Create: `clients/orel-sandbox/dev/1-networking/variables.tf`
- Create: `clients/orel-sandbox/dev/1-networking/locals.tf`
- Create: `clients/orel-sandbox/dev/1-networking/data.tf`

**Step 1: Write variables.tf**

These are the root-level variable declarations. Values come from `.auto.tfvars`.

```hcl
# clients/orel-sandbox/dev/1-networking/variables.tf

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "apis" {
  description = "List of GCP APIs to enable"
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    cidr                  = string
    purpose               = optional(string, "PRIVATE")
    role                  = optional(string, null)
    private_google_access = optional(bool, true)
    secondary_ranges = optional(map(object({
      cidr = string
    })), {})
  }))
}

variable "firewall_rules" {
  description = "Map of firewall rule configurations"
  type = map(object({
    direction          = optional(string, "INGRESS")
    priority           = optional(number, 1000)
    action             = string
    protocol           = string
    ports              = optional(list(string), [])
    source_ranges      = optional(list(string), [])
    destination_ranges = optional(list(string), [])
    target_tags        = optional(list(string), [])
    source_tags        = optional(list(string), [])
  }))
  default = {}
}

variable "nat_config" {
  description = "Cloud NAT configuration. Set to null to skip NAT creation."
  type = object({
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    min_ports_per_vm                   = optional(number, 64)
    max_ports_per_vm                   = optional(number, 4096)
    log_filter                         = optional(string, "ERRORS_ONLY")
  })
  default = null
}

variable "psa_ranges" {
  description = "Map of Private Services Access IP range allocations"
  type = map(object({
    cidr = string
  }))
  default = {}
}
```

**Step 2: Write locals.tf**

```hcl
# clients/orel-sandbox/dev/1-networking/locals.tf

locals {
  # Common labels/tags can be defined here for future use
  # Currently empty - will be populated as needed in later stages
}
```

**Step 3: Write data.tf**

```hcl
# clients/orel-sandbox/dev/1-networking/data.tf

# Data sources for this layer
# Currently empty - no external data sources needed for networking
# Future layers will use terraform_remote_state to read this layer's outputs
```

**Step 4: Commit**

```bash
git add clients/orel-sandbox/dev/1-networking/variables.tf \
        clients/orel-sandbox/dev/1-networking/locals.tf \
        clients/orel-sandbox/dev/1-networking/data.tf
git commit -m "feat(sandbox/networking): add variable declarations, locals, and data sources"
```

---

## Task 8: Client Environment - main.tf + outputs.tf

**Files:**
- Create: `clients/orel-sandbox/dev/1-networking/main.tf`
- Create: `clients/orel-sandbox/dev/1-networking/outputs.tf`

**Step 1: Write main.tf - the module call**

```hcl
# clients/orel-sandbox/dev/1-networking/main.tf

module "networking" {
  source = "../../../../modules/networking"

  project_id     = var.project_id
  region         = var.region
  vpc_name       = var.vpc_name
  apis           = var.apis
  subnets        = var.subnets
  firewall_rules = var.firewall_rules
  nat_config     = var.nat_config
  psa_ranges     = var.psa_ranges
}
```

**Step 2: Write outputs.tf - pass-through outputs**

```hcl
# clients/orel-sandbox/dev/1-networking/outputs.tf

output "vpc_id" {
  description = "The ID of the VPC network"
  value       = module.networking.vpc_id
}

output "vpc_self_link" {
  description = "The self link of the VPC network"
  value       = module.networking.vpc_self_link
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = module.networking.vpc_name
}

output "subnet_ids" {
  description = "Map of subnet name => subnet ID"
  value       = module.networking.subnet_ids
}

output "subnet_self_links" {
  description = "Map of subnet name => subnet self link"
  value       = module.networking.subnet_self_links
}

output "subnet_cidrs" {
  description = "Map of subnet name => primary CIDR"
  value       = module.networking.subnet_cidrs
}

output "gke_subnet_name" {
  description = "Full name of the GKE subnet"
  value       = module.networking.gke_subnet_name
}

output "pod_secondary_range_name" {
  description = "Name of the secondary range for GKE pods"
  value       = module.networking.pod_secondary_range_name
}

output "service_secondary_range_name" {
  description = "Name of the secondary range for GKE services"
  value       = module.networking.service_secondary_range_name
}

output "psa_connection_id" {
  description = "ID of the PSA connection"
  value       = module.networking.psa_connection_id
}

output "router_id" {
  description = "ID of the Cloud Router"
  value       = module.networking.router_id
}

output "nat_id" {
  description = "ID of the Cloud NAT"
  value       = module.networking.nat_id
}
```

**Step 3: Commit**

```bash
git add clients/orel-sandbox/dev/1-networking/main.tf \
        clients/orel-sandbox/dev/1-networking/outputs.tf
git commit -m "feat(sandbox/networking): add module call and pass-through outputs"
```

---

## Task 9: Client Environment - networking.auto.tfvars

**Files:**
- Create: `clients/orel-sandbox/dev/1-networking/networking.auto.tfvars`
- Modify: `.gitignore` - remove `*.tfvars` exclusion, add specific exclusions instead

**Step 1: Update .gitignore**

The default Terraform `.gitignore` excludes all `.tfvars` files. Since our `.auto.tfvars` files don't contain secrets (project_id is not a secret, CIDRs are not secrets), we WANT them in version control. Secrets will be handled by environment variables or Workload Identity.

Replace the tfvars section in `.gitignore`:

```gitignore
# Exclude tfvars files that may contain secrets
# BUT include .auto.tfvars which contain non-secret configuration
*.tfvars
!*.auto.tfvars
```

**Step 2: Write networking.auto.tfvars**

```hcl
# clients/orel-sandbox/dev/1-networking/networking.auto.tfvars

# =============================================================================
# Project Configuration
# =============================================================================

project_id = "orel-bh-sandbox"
region     = "europe-west1"
vpc_name   = "orel-sandbox-dev"

# =============================================================================
# APIs to Enable
# =============================================================================

apis = [
  "compute.googleapis.com",
  "container.googleapis.com",
  "servicenetworking.googleapis.com",
  "sqladmin.googleapis.com",
]

# =============================================================================
# Subnets
# =============================================================================

subnets = {
  "gke-subnet" = {
    cidr = "10.0.0.0/20"
    secondary_ranges = {
      "pods"     = { cidr = "10.4.0.0/14" }
      "services" = { cidr = "10.8.0.0/20" }
    }
  }
  "proxy-only-subnet" = {
    cidr    = "10.0.16.0/23"
    purpose = "REGIONAL_MANAGED_PROXY"
    role    = "ACTIVE"
  }
}

# =============================================================================
# Firewall Rules (deny-all + explicit whitelist)
# =============================================================================

firewall_rules = {
  "deny-all-ingress" = {
    action        = "deny"
    protocol      = "all"
    priority      = 65534
    source_ranges = ["0.0.0.0/0"]
  }

  "allow-iap-ssh" = {
    action        = "allow"
    protocol      = "tcp"
    ports         = ["22"]
    source_ranges = ["35.235.240.0/20"]
  }

  "allow-health-checks" = {
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
    target_tags   = ["gke-node"]
  }

  "allow-proxy-to-backends" = {
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["10.0.16.0/23"]
    target_tags   = ["gke-node"]
  }
}

# =============================================================================
# Cloud NAT
# =============================================================================

nat_config = {
  min_ports_per_vm = 64
  max_ports_per_vm = 4096
  log_filter       = "ERRORS_ONLY"
}

# =============================================================================
# Private Services Access (for Cloud SQL)
# =============================================================================

psa_ranges = {
  "google-managed-services" = {
    cidr = "10.16.0.0/16"
  }
}
```

**Step 3: Commit**

```bash
git add .gitignore clients/orel-sandbox/dev/1-networking/networking.auto.tfvars
git commit -m "feat(sandbox/networking): add tfvars configuration and update gitignore for auto.tfvars"
```

---

## Task 10: Validate - terraform init + validate + plan

**Step 1: Initialize Terraform**

```bash
cd clients/orel-sandbox/dev/1-networking
terraform init
```

Expected: Successful init, provider downloaded, backend configured with GCS.

**Step 2: Validate**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

**Step 3: Format check entire project**

```bash
cd ../../../../
terraform fmt -recursive -check
```

Expected: No output (all files formatted).

**Step 4: Plan**

```bash
cd clients/orel-sandbox/dev/1-networking
terraform plan
```

Expected: Plan showing creation of:
- 4x `google_project_service` (APIs)
- 1x `google_compute_network` (VPC)
- 2x `google_compute_subnetwork` (gke-subnet + proxy-only)
- 4x `google_compute_firewall` (deny-all + 3 allow rules)
- 1x `google_compute_router`
- 1x `google_compute_router_nat`
- 1x `google_compute_global_address` (PSA range)
- 1x `google_service_networking_connection` (PSA peering)

Total: ~15 resources to create.

**Step 5: Commit any format changes**

```bash
git add -A
git commit -m "chore: format all terraform files"
```
(Only if there were format changes)

---

## Task 11: Apply and Console Verification

**Step 1: Apply**

```bash
cd clients/orel-sandbox/dev/1-networking
terraform apply
```

Review the plan and type `yes`.

**Step 2: Verify in GCP Console**

After apply completes, verify these items in the GCP Console:

1. **VPC Networks** (VPC network > VPC networks):
   - `orel-sandbox-dev` VPC exists
   - Routing mode: Regional
   - No auto-created subnets

2. **Subnets** (VPC network > VPC networks > click the VPC):
   - `orel-sandbox-dev-gke-subnet` in europe-west1, CIDR 10.0.0.0/20
   - Secondary ranges: pods (10.4.0.0/14), services (10.8.0.0/20)
   - Private Google Access: ON
   - `orel-sandbox-dev-proxy-only-subnet` in europe-west1, CIDR 10.0.16.0/23
   - Purpose: REGIONAL_MANAGED_PROXY

3. **Firewall Rules** (VPC network > Firewall):
   - 4 rules prefixed with `orel-sandbox-dev-`
   - deny-all-ingress at priority 65534
   - allow rules at priority 1000

4. **Cloud NAT** (Network services > Cloud NAT):
   - `orel-sandbox-dev-nat` in europe-west1
   - Auto-allocated IPs
   - Logging: Errors only

5. **Private Services Access** (VPC network > VPC networks > click VPC > Private services access):
   - Allocated range: 10.16.0.0/16
   - Connection to servicenetworking.googleapis.com

6. **APIs** (APIs & Services > Enabled APIs):
   - Compute Engine API
   - Kubernetes Engine API
   - Service Networking API
   - Cloud SQL Admin API

**Step 3: Save terraform output**

```bash
terraform output
```

Verify all outputs have values.

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: add lock file after successful init"
```
(If `.terraform.lock.hcl` was created)

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Directory structure | directories only |
| 2 | Module variables.tf | modules/networking/variables.tf |
| 3 | Module locals.tf | modules/networking/locals.tf |
| 4 | Module main.tf (all resources) | modules/networking/main.tf |
| 5 | Module outputs.tf | modules/networking/outputs.tf |
| 6 | Client versions + provider + backend | 3 files in clients/.../1-networking/ |
| 7 | Client variables + locals + data | 3 files in clients/.../1-networking/ |
| 8 | Client main.tf + outputs.tf | 2 files in clients/.../1-networking/ |
| 9 | Client tfvars + gitignore update | networking.auto.tfvars + .gitignore |
| 10 | Validate: init + validate + plan | commands only |
| 11 | Apply + console verification | commands only |
