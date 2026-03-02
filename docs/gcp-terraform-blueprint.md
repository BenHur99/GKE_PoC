# GCP Terraform Blueprint - Production Delivery Guide

**Purpose:** Reference document for building high-quality GCP Terraform projects for clients.
An agent (or engineer) with this document should have enough context to build a complete project.

**Last Updated:** 2026-03-02

---

## 1. Architecture Pattern: Shared Code + tfvars

One set of `.tf` files per layer. Configuration varies per client/environment via `tfvars` files only.

```
{product}/
├── networking/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── locals.tf
│   ├── data.tf
│   ├── providers.tf
│   ├── backend.tf          ← dynamic (prefix at init time)
│   ├── versions.tf
│   └── tfvars/
│       ├── orel/
│       │   └── dev.tfvars
│       └── {client}/
│           ├── dev.tfvars
│           └── prod.tfvars
├── database/               ← future layer
├── compute/                ← future layer
└── identity/               ← future layer
modules/                    ← shared across all layers
```

**Why this pattern:**
- Code written once, tested once, maintained once
- Adding a client/env = adding a tfvars file (no code changes)
- State isolation per client/env via dynamic backend prefix
- No drift between environments (same code, different config)

## 2. Layer-Based State Isolation

Each infrastructure layer has its own Terraform state file. Layers reference each other via `terraform_remote_state`.

**Layer order:**
1. `networking` - VPC, subnets, firewall, NAT, PSA
2. `database` - Cloud SQL (reads networking outputs)
3. `compute` - GKE cluster (reads networking + database outputs)
4. `identity` - Workload Identity, IAM (reads compute outputs)

**Backend pattern (dynamic):**
```hcl
terraform {
  backend "gcs" {
    bucket = "terraform-states-gcs"
    # prefix set at init: terraform init -backend-config="prefix=CLIENT/ENV/LAYER"
  }
}
```

**State key pattern:** `{client}/{env}/{layer}`
Example: `orel/dev/networking`

**Cross-layer data source:**
```hcl
data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = "terraform-states-gcs"
    prefix = "${var.client_name}/${var.environment}/networking"
  }
}
```

## 3. Naming Convention

**Format:** `{client}-{product}-{env}-{region_short}-{resource_type}-{name}`

**Region short mapping (in locals.tf):**
| Region | Short |
|--------|-------|
| europe-west1 | euw1 |
| europe-west2 | euw2 |
| us-central1 | usc1 |
| us-east1 | use1 |
| asia-east1 | ase1 |

**naming_prefix** is computed once in `locals.tf`:
```hcl
locals {
  region_short  = lookup(local.region_short_map, var.region, replace(var.region, "/[aeiou-]/", ""))
  naming_prefix = "${var.client_name}-${var.product_name}-${var.environment}-${local.region_short}"
}
```

**Examples:**
| Resource | Name |
|----------|------|
| VPC | orel-gob-dev-euw1-vpc-main |
| Subnet | orel-gob-dev-euw1-subnet-gke |
| Firewall | orel-gob-dev-euw1-fw-deny-all-ingress |
| Cloud NAT | orel-gob-dev-euw1-main-nat |
| Cloud Router | orel-gob-dev-euw1-main-router |

## 4. Module Design

### Per-Resource Modules (Current - Learning/PoC)

Each module wraps a single GCP resource (or tightly-coupled pair like router + NAT).
Modules are simple wrappers - they receive a pre-computed `name` from the caller.

**Module file structure:**
```
modules/{resource}/
├── main.tf          # Single resource (or coupled pair)
├── variables.tf     # Inputs
└── outputs.tf       # id, name, self_link
```

**Current modules:**
| Module | Resources | Use Case |
|--------|-----------|----------|
| vpc | google_compute_network | VPC network |
| subnet | google_compute_subnetwork | Subnets with secondary ranges |
| firewall_rule | google_compute_firewall | Individual firewall rules |
| cloud_nat | google_compute_router + google_compute_router_nat | NAT gateway |
| psa | google_compute_global_address + google_service_networking_connection | Private Services Access |
| project_api | google_project_service | API enablement |

### Community Modules (Recommended for Production)

For production delivery, prefer `terraform-google-modules/*`:
- `terraform-google-modules/network/google` - VPC, subnets, routes, firewall
- `terraform-google-modules/kubernetes-engine/google` - GKE cluster
- `terraform-google-modules/sql-db/google` - Cloud SQL
- `terraform-google-modules/iam/google` - IAM bindings

**Hybrid approach:** Use community modules for complex resources (GKE, SQL), custom per-resource modules for simple/custom needs.

## 5. Variable Design

All collection variables use `map(object)` with `for_each` (never `list`).
Even singleton resources use a single-entry map for consistency.

**Pattern:**
```hcl
variable "vpcs" {
  type = map(object({
    # no required fields for VPC - all config is in naming
  }))
  default = {}
}

variable "subnets" {
  type = map(object({
    vpc_key               = string
    cidr                  = string
    purpose               = optional(string, "PRIVATE")
    role                  = optional(string, null)
    private_google_access = optional(bool, true)
    secondary_ranges = optional(map(object({
      cidr = string
    })), {})
  }))
  default = {}
}
```

**Key principles:**
- `optional()` with sensible defaults for all non-required fields
- `vpc_key` field to reference other resources by map key
- Resources link via map keys, not IDs (resolved in main.tf)

## 6. Layer Orchestration (main.tf)

The layer's `main.tf` orchestrates modules with `for_each`:

```hcl
module "vpcs" {
  for_each = var.vpcs
  source   = "../../modules/vpc"

  name       = "${local.naming_prefix}-vpc-${each.key}"
  project_id = var.project_id

  depends_on = [module.apis]
}

module "subnets" {
  for_each = var.subnets
  source   = "../../modules/subnet"

  name       = "${local.naming_prefix}-subnet-${each.key}"
  network_id = module.vpcs[each.value.vpc_key].id
  # ... other fields from each.value
}
```

**Module source path:** `../../modules/{module_name}` (from `gob/{layer}/`)

## 7. Full Manifest Set Per Layer

Every layer MUST have all 8 files:

| File | Purpose |
|------|---------|
| main.tf | Module calls with for_each |
| variables.tf | Variable declarations (map(object) with optional()) |
| outputs.tf | Pass-through outputs from modules |
| locals.tf | naming_prefix, region_short, computed values |
| data.tf | Data sources (terraform_remote_state for cross-layer) |
| providers.tf | Provider configuration |
| backend.tf | Dynamic GCS backend |
| versions.tf | Terraform + provider version constraints |

## 8. tfvars File Structure

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
  "compute.googleapis.com",
  "container.googleapis.com",
]

# =============================================================================
# Resource-specific sections (VPCs, Subnets, Firewall, etc.)
# =============================================================================
```

## 9. Running Terraform Commands

**From the layer directory (Git Bash):**
```bash
cd gob/networking

# Initialize with client/env-specific state prefix
terraform init -backend-config="prefix=orel/dev/networking"

# Validate syntax
terraform validate

# Plan with client/env-specific config
terraform plan -var-file=tfvars/orel/dev.tfvars

# Apply
terraform apply -var-file=tfvars/orel/dev.tfvars

# Destroy
terraform destroy -var-file=tfvars/orel/dev.tfvars
```

**Switching client/env (re-init required):**
```bash
terraform init -reconfigure -backend-config="prefix=newclient/prod/networking"
terraform plan -var-file=tfvars/newclient/prod.tfvars
```

**PowerShell note:** Wrap `-var-file` in single quotes: `'-var-file=tfvars/orel/dev.tfvars'`

## 10. Outputs Pattern

Outputs expose module results as maps (keyed by the same keys used in for_each):

```hcl
output "vpc_ids" {
  value = { for k, v in module.vpcs : k => v.id }
}

output "subnet_ids" {
  value = { for k, v in module.subnets : k => v.id }
}
```

## 11. Git & Version Control

**.gitignore:**
```
.terraform/
*.tfstate
*.tfstate.*
crash.log
crash.*.log
*.tfplan
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraform.tfstate.lock.info
.terraformrc
terraform.rc
```

**All tfvars are tracked in git** (non-secret configuration).
Secrets should be in environment variables, Secret Manager, or CI/CD variables.

**Commit convention:** `feat()`, `fix()`, `refactor()`, `docs()`, `chore()`

## 12. GCP-Specific Best Practices

- **Always enable APIs first** with `depends_on = [module.apis]`
- **Use Private Google Access** on all subnets (GKE nodes pull images without public IP)
- **Cloud NAT** for egress-only internet access from private subnets
- **PSA (Private Services Access)** for managed services like Cloud SQL
- **REGIONAL_MANAGED_PROXY** subnet required for internal HTTP(S) load balancers
- **Secondary ranges** on GKE subnet for pods and services
- **Deny-all default** firewall rule with high priority (65534), then specific allows

## 13. Security Baseline

Firewall rules (from most restrictive to least):
1. `deny-all-ingress` (priority 65534) - Default deny all
2. `allow-iap-ssh` - IAP range (35.235.240.0/20) TCP:22 only
3. `allow-health-checks` - Google health check ranges, tagged to GKE nodes
4. `allow-proxy-to-backends` - Proxy subnet to GKE nodes for ALB

## 14. Adding a New Client

1. Create tfvars: `gob/{layer}/tfvars/{client}/{env}.tfvars`
2. Update identity variables: `client_name`, `project_id`, etc.
3. Adjust network CIDRs if needed
4. Init with new prefix: `terraform init -backend-config="prefix={client}/{env}/{layer}"`
5. Plan and apply: `terraform plan -var-file=tfvars/{client}/{env}.tfvars`

## 15. CI/CD Pipeline Pattern

```yaml
# Per client/env/layer:
jobs:
  terraform:
    env:
      TF_LAYER: networking
      TF_CLIENT: orel
      TF_ENV: dev
    steps:
      - run: cd gob/$TF_LAYER
      - run: terraform init -backend-config="prefix=$TF_CLIENT/$TF_ENV/$TF_LAYER"
      - run: terraform plan -var-file=tfvars/$TF_CLIENT/$TF_ENV.tfvars -out=plan.tfplan
      - run: terraform apply plan.tfplan  # only on main branch
```
