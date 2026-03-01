# Stage 1: Bootstrap & Modular Networking - Design Document

**Date:** 2026-03-01
**Author:** Orel + Claude
**Status:** SUPERSEDED by 2026-03-01-bootstrap-networking-design-v2.md

## Context

Building a production-ready, multi-tenant IaC product for GKE on GCP.
This is Stage 1 of a 7-stage roadmap. The foundation must support all future stages
without refactoring the structure.

**Constraints:**
- Budget: $70/month (ephemeral infrastructure)
- Project: orel-bh-sandbox
- Region: europe-west1
- State bucket: terraform-states-gcs (pre-created)
- Terraform >= 1.6, Google Provider >= 6.x

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| VPC model | Standalone VPC per env | Simpler for PoC, can evolve to Shared VPC |
| Project structure | Flat module + complex variables | Balance of genericity and simplicity |
| State isolation | Layer-per-state (Terragrunt-like) | Blast radius isolation, parallel work, fast plans |
| Firewall strategy | Explicit deny-all + whitelist | Production-grade security posture |
| Subnet variable type | map(object) | Stable for_each keys, no index-shift destruction |
| Module file layout | Single main.tf per module | All resources in one file, for_each driven |
| Environment file layout | Full manifests per layer | main, variables, outputs, locals, data, providers, backend, versions, tfvars |

## Directory Structure

```
GKE_PoC/
├── clients/
│   └── orel-sandbox/
│       └── dev/
│           ├── 1-networking/
│           │   ├── main.tf
│           │   ├── variables.tf
│           │   ├── outputs.tf
│           │   ├── locals.tf
│           │   ├── data.tf
│           │   ├── providers.tf
│           │   ├── backend.tf
│           │   ├── versions.tf
│           │   └── networking.auto.tfvars
│           ├── 2-database/          # Stage 2
│           ├── 3-compute/           # Stage 3
│           └── 4-identity/          # Stage 4
├── modules/
│   └── networking/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── locals.tf
└── docs/
    └── plans/
```

Each layer is an independent root module with its own state file in GCS.

## Data Model

### Subnets - map(object)

```hcl
variable "subnets" {
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
```

Example tfvars:
```hcl
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
```

### Firewall Rules - map(object)

```hcl
variable "firewall_rules" {
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
}
```

### NAT Configuration - object

```hcl
variable "nat_config" {
  type = object({
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    min_ports_per_vm                   = optional(number, 64)
    max_ports_per_vm                   = optional(number, 4096)
    log_filter                         = optional(string, "ERRORS_ONLY")
  })
  default = {}
}
```

### PSA Ranges - map(object)

```hcl
variable "psa_ranges" {
  type = map(object({
    cidr = string
  }))
  default = {}
}
```

## Network Architecture

```
                         Internet
                            │
                       Cloud NAT (egress only)
                            │
                ┌───────────▼────────────────────────────┐
                │              Custom VPC                  │
                │                                          │
                │  gke-subnet (10.0.0.0/20)               │
                │    ├── Pods:     10.4.0.0/14            │
                │    └── Services: 10.8.0.0/20            │
                │                                          │
                │  proxy-only-subnet (10.0.16.0/23)       │
                │    purpose: REGIONAL_MANAGED_PROXY       │
                │                                          │
                │           VPC Peering (PSA)              │
                │               │                          │
                │  Google-managed (10.16.0.0/16)           │
                │    └── Cloud SQL (private IP)            │
                └──────────────────────────────────────────┘

Firewall: deny-all → allow IAP SSH → allow health-checks → allow proxy→backends
```

## Resources Created

| Component | Terraform Resource | Driven By |
|-----------|-------------------|-----------|
| VPC | google_compute_network | Single resource |
| Subnets | google_compute_subnetwork | for_each on var.subnets |
| Firewall | google_compute_firewall | for_each on var.firewall_rules |
| Cloud Router | google_compute_router | Single resource |
| Cloud NAT | google_compute_router_nat | Config from var.nat_config |
| PSA Allocation | google_compute_global_address | for_each on var.psa_ranges |
| PSA Connection | google_service_networking_connection | Single, depends on allocations |
| APIs | google_project_service | for_each on var.apis |

## Module Outputs

| Output | Purpose | Consumer |
|--------|---------|----------|
| vpc_id | VPC identifier | All layers |
| vpc_self_link | VPC self link | GKE, Cloud SQL |
| vpc_name | VPC name | Firewall rules, display |
| subnet_ids | map: name => id | GKE, Cloud SQL |
| subnet_self_links | map: name => self_link | GKE |
| subnet_cidrs | map: name => CIDR | Reference |
| pod_secondary_range_name | GKE pod range name | Compute layer |
| service_secondary_range_name | GKE service range name | Compute layer |
| psa_connection_id | PSA dependency | Database layer |
| router_id | Cloud Router ID | Reference |
| nat_id | Cloud NAT ID | Reference |

## Cross-Layer Communication

Layers reference each other via `terraform_remote_state`:
```hcl
data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = "terraform-states-gcs"
    prefix = "orel-sandbox/dev/networking"
  }
}
```

## CIDR Allocation Summary

| Range | Purpose | Size |
|-------|---------|------|
| 10.0.0.0/20 | GKE nodes | 4,094 IPs |
| 10.4.0.0/14 | GKE pods (secondary) | 262,142 IPs |
| 10.8.0.0/20 | GKE services (secondary) | 4,094 IPs |
| 10.0.16.0/23 | ALB proxy-only | 510 IPs |
| 10.16.0.0/16 | PSA (Cloud SQL) | 65,534 IPs |
