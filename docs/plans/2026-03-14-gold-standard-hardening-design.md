# Gold Standard Hardening — Design Document

**Date:** 2026-03-14
**Status:** Approved
**Scope:** Terraform code quality, security, testing — Helm excluded

## Goal

Elevate the existing per-resource Terraform modules and layer code to enterprise-grade
"Gold Standard" quality. This baseline will later be converted into reusable Claude Code
Skills for real-world client projects at Sela.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Module strategy | Per-resource (custom) first | Already built, improve to Gold Standard. Official/hybrid tracks later |
| Multi-env promotion | tfvars-based (A) | HashiCorp-recommended, already in place |
| Testing/policy tools | Terraform-native only | No external tools (tflint, OPA, Checkov) |
| Git strategy | GitHub Flow | Feature branches + PRs, no GitFlow overhead |
| Branching | `feat/gold-standard-hardening` | All changes in single feature branch |

## Scope — What's Included

- All 13 modules under `modules/`
- All 4 layers under `gob/` (networking, database, compute, automation)
- CI/CD workflow (`.github/workflows/terraform.yml`)
- Documentation updates

## Scope — What's Excluded

- Helm chart (`helm/online-boutique/`)
- Official GCP module track (future project)
- Stage 7 (Monitoring & Polish)

---

## Phase 1 — Security & Compliance

### 1.1 GCP Labels System
- Add `labels` variable to every module that supports labels
- Define common labels in each layer's `locals.tf`: client, product, environment, managed_by, layer
- Pass labels from layer → module via variable
- **Resources that support labels:** VPC, subnet, firewall, Cloud NAT router, Cloud SQL, GKE cluster, node pool, service account, static IP

### 1.2 IAM Hardening
- Replace `roles/editor` on CI/CD SA with specific roles:
  - `roles/container.admin` — GKE operations
  - `roles/compute.admin` — compute resources
  - `roles/cloudsql.admin` — Cloud SQL operations
  - `roles/storage.admin` — state bucket access
  - Keep existing: `servicenetworking.networksAdmin`, `resourcemanager.projectIamAdmin`, `iam.serviceAccountAdmin`

### 1.3 GKE Security Hardening
- Add to `gke_cluster` module (as optional variables with secure defaults):
  - `enable_network_policy = true`
  - `enable_shielded_nodes = true`
  - `logging_service = "logging.googleapis.com/kubernetes"`
  - `monitoring_service = "monitoring.googleapis.com/kubernetes"`
  - `maintenance_window_start_time = "02:00"` (daily, UTC)

### 1.4 Sensitive Outputs
- Mark `sensitive = true` on:
  - `cluster_endpoints` (compute layer + module)
  - `cluster_ca_certificates` (already done)
  - `sql_private_ips` (database layer + module)

---

## Phase 2 — Module Quality

### 2.1 `terraform {}` Blocks
- Add `required_providers` block to all 13 modules:
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

### 2.2 `validation {}` Blocks
- Add validation to all variables with constrained values:
  - `firewall_rule`: direction (INGRESS/EGRESS), action (allow/deny)
  - `static_ip`: address_type (EXTERNAL/INTERNAL), network_tier (PREMIUM/STANDARD)
  - `cloud_nat`: nat_ip_allocate_option, log_filter
  - `gke_cluster`: release_channel, master_ipv4_cidr_block (/28 CIDR)
  - `gke_node_pool`: machine_type format, disk_type
  - Layer variables: region, environment, CIDR format

### 2.3 DRY Locals
- Extract `region_short_map` and `naming_prefix` to a shared `naming` module:
  ```
  modules/naming/
  ├── main.tf       # locals computation
  ├── variables.tf  # client_name, product_name, environment, region
  └── outputs.tf    # naming_prefix, region_short
  ```
- All 4 layers call this module instead of duplicating locals

### 2.4 `optional()` Consistency
- Audit all module variables — replace `default = ""` with `optional(string, "")` in object types
- Ensure all map(object) variable definitions use optional() with explicit defaults

---

## Phase 3 — Reliability & Testing

### 3.1 Terraform Tests
- Create `.tftest.hcl` files for critical modules:
  - `modules/vpc/vpc.tftest.hcl` — validates VPC creation, no auto-subnets
  - `modules/gke_cluster/gke_cluster.tftest.hcl` — validates private cluster, WI enabled
  - `modules/firewall_rule/firewall_rule.tftest.hcl` — validates direction, priority
  - `modules/cloud_sql/cloud_sql.tftest.hcl` — validates private IP, IAM auth

### 3.2 `precondition` / `postcondition`
- GKE cluster: precondition that subnet has secondary ranges
- Cloud SQL: precondition that PSA is configured (VPC has private service connection)
- VPC: postcondition that auto_create_subnetworks is false

### 3.3 `lifecycle` Rules
- `prevent_destroy = true` on Cloud SQL (configurable via variable, default true)
- `prevent_destroy = true` on VPC (configurable via variable, default true)
- Document that dev overrides to false via tfvars

### 3.4 Cloud SQL Backup Pattern
- Add backup config variables to `cloud_sql` module (backup_enabled, backup_start_time, pitr_enabled)
- Dev tfvars: explicitly set `backup_enabled = false` with comment
- Show prod pattern in comments

---

## Phase 4 — Multi-Environment Readiness

### 4.1 tfvars Templates
- Create `staging.tfvars` and `prod.tfvars` examples for networking layer
- Include comments explaining differences from dev (e.g., no 0.0.0.0/0, deletion_protection = true)

### 4.2 Documentation Comments
- Add explanatory comments in dev.tfvars for security-relevant decisions
- Document master_authorized_networks 0.0.0.0/0 as dev-only

### 4.3 Backend Bucket
- Keep hardcoded for now (low priority, stable value)
- Document in CLAUDE.md that bucket name is per-GCP-project

---

## Phase 5 — Skills Preparation

### 5.1 Decision Framework
- Document when to use custom vs official vs hybrid modules
- Input criteria: team size, compliance needs, timeline, customization level
- Output: recommended track with rationale

### 5.2 Module Track Documentation
- Document the custom module patterns and conventions
- This becomes the source material for Claude Code Skills extraction

---

## Verification

After all phases complete:
- [ ] `terraform validate` passes on all 4 layers
- [ ] All modules have `terraform {}` + `validation {}` blocks
- [ ] All resources have GCP labels
- [ ] No `roles/editor` in IAM bindings
- [ ] GKE has network policy, shielded nodes, maintenance window
- [ ] Sensitive outputs marked
- [ ] At least 4 `.tftest.hcl` files exist
- [ ] DRY — no duplicated locals across layers
- [ ] dev.tfvars has explanatory comments on security decisions
