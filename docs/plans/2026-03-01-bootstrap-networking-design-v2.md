# Stage 1: Bootstrap & Modular Networking - Design Document v2

**Date:** 2026-03-01
**Author:** Orel + Claude
**Status:** Approved
**Supersedes:** 2026-03-01-bootstrap-networking-design.md

## Context

Building a production-ready, multi-tenant IaC product for GKE on GCP (Google Online Boutique - GOB).
This is Stage 1 of a 7-stage roadmap.

**Constraints:**
- Budget: $70/month (ephemeral infrastructure)
- Project: orel-bh-sandbox
- Region: europe-west1
- State bucket: terraform-states-gcs (pre-created)
- Terraform >= 1.6, Google Provider >= 6.x

## Key Architecture Changes from v1

1. **Per-resource modules** instead of one monolithic networking module
2. **All module calls use for_each** - even singletons (consistency over pragmatism)
3. **Unified naming convention** across all resources and layers
4. **Each module is a single resource wrapper** - the layer's main.tf orchestrates them

## Naming Convention

**Format:** `{client}-{product}-{env}-{region_short}-{resource_type}-{name}`

**Components:**
| Component | Source | Example |
|-----------|--------|---------|
| client | var.client_name | sela |
| product | var.product_name | gob |
| env | var.environment | dev |
| region_short | computed from var.region | euw1 |
| resource_type | hardcoded per module | vpc, subnet, fw, router, nat, psa |
| name | map key from tfvars | main, gke, proxy |

**Region short mapping:**
- europe-west1 -> euw1
- us-central1 -> usc1
- asia-east1 -> ase1

**Examples:**
| Resource | Full Name |
|----------|-----------|
| VPC | sela-gob-dev-euw1-vpc-main |
| GKE Subnet | sela-gob-dev-euw1-subnet-gke |
| Proxy Subnet | sela-gob-dev-euw1-subnet-proxy |
| Firewall deny-all | sela-gob-dev-euw1-fw-deny-all-ingress |
| Cloud Router | sela-gob-dev-euw1-router-main |
| Cloud NAT | sela-gob-dev-euw1-nat-main |
| PSA Range | sela-gob-dev-euw1-psa-google-managed |
| GKE Cluster (future) | sela-gob-dev-euw1-gke-main |
| Cloud SQL (future) | sela-gob-dev-euw1-sql-main |

## Directory Structure

```
GKE_PoC/
├── clients/
│   └── sela/
│       └── dev/
│           ├── 1-networking/
│           │   ├── main.tf              # Module calls with for_each
│           │   ├── variables.tf         # Variable declarations
│           │   ├── outputs.tf           # Pass-through outputs
│           │   ├── locals.tf            # naming_prefix, region_short
│           │   ├── data.tf              # Data sources
│           │   ├── providers.tf         # Provider config
│           │   ├── backend.tf           # GCS backend
│           │   ├── versions.tf          # Version constraints
│           │   └── networking.auto.tfvars
│           ├── 2-database/              # Stage 2
│           ├── 3-compute/               # Stage 3
│           └── 4-identity/              # Stage 4
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── subnet/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── firewall_rule/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloud_nat/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── psa/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── project_api/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── docs/
    └── plans/
```

## Module Specifications

### modules/vpc

**Resource:** google_compute_network

**Variables:**
```hcl
variable "name" {
  description = "Full name of the VPC (naming_prefix + vpc + key)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}
```

**Outputs:** id, self_link, name

### modules/subnet

**Resource:** google_compute_subnetwork

**Variables:**
```hcl
variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "network_id" {
  description = "VPC network ID to attach subnet to"
  type        = string
}

variable "cidr" {
  type = string
}

variable "purpose" {
  type    = string
  default = "PRIVATE"
}

variable "role" {
  type    = string
  default = null
}

variable "private_google_access" {
  type    = bool
  default = true
}

variable "secondary_ranges" {
  type = map(object({
    cidr = string
  }))
  default = {}
}
```

**Outputs:** id, self_link, name, cidr, secondary_range_names (map)

### modules/firewall_rule

**Resource:** google_compute_firewall

**Variables:**
```hcl
variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "network_id" {
  type = string
}

variable "direction" {
  type    = string
  default = "INGRESS"
}

variable "priority" {
  type    = number
  default = 1000
}

variable "action" {
  type = string  # "allow" or "deny"
}

variable "protocol" {
  type = string
}

variable "ports" {
  type    = list(string)
  default = []
}

variable "source_ranges" {
  type    = list(string)
  default = []
}

variable "destination_ranges" {
  type    = list(string)
  default = []
}

variable "target_tags" {
  type    = list(string)
  default = []
}

variable "source_tags" {
  type    = list(string)
  default = []
}
```

**Outputs:** id, name

### modules/cloud_nat

**Resources:** google_compute_router + google_compute_router_nat

**Variables:**
```hcl
variable "name" {
  type = string  # Used for both router and NAT with suffixes
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "network_id" {
  type = string
}

variable "nat_ip_allocate_option" {
  type    = string
  default = "AUTO_ONLY"
}

variable "source_subnetwork_ip_ranges_to_nat" {
  type    = string
  default = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

variable "min_ports_per_vm" {
  type    = number
  default = 64
}

variable "max_ports_per_vm" {
  type    = number
  default = 4096
}

variable "log_filter" {
  type    = string
  default = "ERRORS_ONLY"
}
```

**Outputs:** router_id, nat_id

### modules/psa

**Resources:** google_compute_global_address + google_service_networking_connection

**Variables:**
```hcl
variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "network_id" {
  type = string
}

variable "cidr" {
  type = string
}
```

**Outputs:** address_id, connection_id

### modules/project_api

**Resource:** google_project_service

**Variables:**
```hcl
variable "project_id" {
  type = string
}

variable "api" {
  type = string
}
```

**Outputs:** id

## Layer main.tf Pattern

```hcl
# APIs
module "apis" {
  for_each = toset(var.apis)
  source   = "../../../../modules/project_api"

  project_id = var.project_id
  api        = each.value
}

# VPCs
module "vpcs" {
  for_each = var.vpcs
  source   = "../../../../modules/vpc"

  name       = "${local.naming_prefix}-vpc-${each.key}"
  project_id = var.project_id

  depends_on = [module.apis]
}

# Subnets
module "subnets" {
  for_each = var.subnets
  source   = "../../../../modules/subnet"

  name                  = "${local.naming_prefix}-subnet-${each.key}"
  project_id            = var.project_id
  region                = var.region
  network_id            = module.vpcs[each.value.vpc_key].id
  cidr                  = each.value.cidr
  purpose               = each.value.purpose
  role                  = each.value.role
  private_google_access = each.value.private_google_access
  secondary_ranges      = each.value.secondary_ranges
}

# Firewall Rules
module "firewall_rules" {
  for_each = var.firewall_rules
  source   = "../../../../modules/firewall_rule"

  name               = "${local.naming_prefix}-fw-${each.key}"
  project_id         = var.project_id
  network_id         = module.vpcs[each.value.vpc_key].id
  direction          = each.value.direction
  priority           = each.value.priority
  action             = each.value.action
  protocol           = each.value.protocol
  ports              = each.value.ports
  source_ranges      = each.value.source_ranges
  destination_ranges = each.value.destination_ranges
  target_tags        = each.value.target_tags
  source_tags        = each.value.source_tags
}

# Cloud NAT (includes Router)
module "cloud_nats" {
  for_each = var.cloud_nats
  source   = "../../../../modules/cloud_nat"

  name                               = "${local.naming_prefix}-${each.key}"
  project_id                         = var.project_id
  region                             = var.region
  network_id                         = module.vpcs[each.value.vpc_key].id
  nat_ip_allocate_option             = each.value.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = each.value.source_subnetwork_ip_ranges_to_nat
  min_ports_per_vm                   = each.value.min_ports_per_vm
  max_ports_per_vm                   = each.value.max_ports_per_vm
  log_filter                         = each.value.log_filter
}

# PSA
module "psa_connections" {
  for_each = var.psa_connections
  source   = "../../../../modules/psa"

  name       = "${local.naming_prefix}-psa-${each.key}"
  project_id = var.project_id
  network_id = module.vpcs[each.value.vpc_key].id
  cidr       = each.value.cidr

  depends_on = [module.apis]
}
```

## tfvars Example

```hcl
# Identity
client_name  = "sela"
product_name = "gob"
environment  = "dev"

# Project
project_id = "orel-bh-sandbox"
region     = "europe-west1"

# APIs
apis = [
  "compute.googleapis.com",
  "container.googleapis.com",
  "servicenetworking.googleapis.com",
  "sqladmin.googleapis.com",
]

# VPCs
vpcs = {
  "main" = {}
}

# Subnets
subnets = {
  "gke" = {
    vpc_key = "main"
    cidr    = "10.0.0.0/20"
    secondary_ranges = {
      "pods"     = { cidr = "10.4.0.0/14" }
      "services" = { cidr = "10.8.0.0/20" }
    }
  }
  "proxy" = {
    vpc_key = "main"
    cidr    = "10.0.16.0/23"
    purpose = "REGIONAL_MANAGED_PROXY"
    role    = "ACTIVE"
  }
}

# Firewall Rules
firewall_rules = {
  "deny-all-ingress" = {
    vpc_key       = "main"
    action        = "deny"
    protocol      = "all"
    priority      = 65534
    source_ranges = ["0.0.0.0/0"]
  }
  "allow-iap-ssh" = {
    vpc_key       = "main"
    action        = "allow"
    protocol      = "tcp"
    ports         = ["22"]
    source_ranges = ["35.235.240.0/20"]
  }
  "allow-health-checks" = {
    vpc_key       = "main"
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
    target_tags   = ["gke-node"]
  }
  "allow-proxy-to-backends" = {
    vpc_key       = "main"
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["10.0.16.0/23"]
    target_tags   = ["gke-node"]
  }
}

# Cloud NAT
cloud_nats = {
  "main" = {
    vpc_key = "main"
  }
}

# PSA
psa_connections = {
  "google-managed" = {
    vpc_key = "main"
    cidr    = "10.16.0.0/16"
  }
}
```

## Network Architecture (unchanged)

```
                         Internet
                            |
                       Cloud NAT (egress only)
                            |
                +-----------v------------------------------------+
                |              Custom VPC                          |
                |                                                  |
                |  sela-gob-dev-euw1-subnet-gke (10.0.0.0/20)    |
                |    +-- Pods:     10.4.0.0/14                    |
                |    +-- Services: 10.8.0.0/20                    |
                |                                                  |
                |  sela-gob-dev-euw1-subnet-proxy (10.0.16.0/23)  |
                |    purpose: REGIONAL_MANAGED_PROXY               |
                |                                                  |
                |           VPC Peering (PSA)                      |
                |               |                                  |
                |  Google-managed (10.16.0.0/16)                   |
                |    +-- Cloud SQL (private IP)                    |
                +--------------------------------------------------+

Firewall: deny-all -> allow IAP SSH -> allow health-checks -> allow proxy->backends
```

## CIDR Allocation (unchanged)

| Range | Purpose | Size |
|-------|---------|------|
| 10.0.0.0/20 | GKE nodes | 4,094 IPs |
| 10.4.0.0/14 | GKE pods (secondary) | 262,142 IPs |
| 10.8.0.0/20 | GKE services (secondary) | 4,094 IPs |
| 10.0.16.0/23 | ALB proxy-only | 510 IPs |
| 10.16.0.0/16 | PSA (Cloud SQL) | 65,534 IPs |
