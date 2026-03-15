---
paths:
  - "gob/**/*"
  - "modules/**/*"
---

# Terraform Conventions

## Module Structure
- Each module wraps a single GCP resource (or tightly-coupled pair like router+NAT)
- Module files: `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf` — nothing else
- `providers.tf` contains the `terraform { required_version / required_providers }` block — NOT main.tf
- Single `main.tf` contains all resources — no splitting by resource type
- Modules are simple wrappers — they receive a pre-computed `name` from the caller

## Layer Structure
- Layer files: `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `data.tf`, `providers.tf`, `backend.tf`, `versions.tf`
- Client config: `tfvars/{client}/{env}.tfvars` per layer
- Layer `main.tf` always calls `module "naming"` first to compute `naming_prefix` and `common_labels`
- `locals.tf` holds only `naming_prefix = module.naming.prefix` — region_short_map lives in `modules/naming/`
- Cross-layer data: use `terraform_remote_state` in `data.tf`

## Naming Module
- Shared module at `modules/naming/` eliminates DRY violation across layers
- Inputs: `client_name`, `product_name`, `environment`, `region`, `layer`, `extra_labels`
- Outputs: `prefix`, `region_short`, `common_labels`
- All layers call it as their first module; pass `labels = module.naming.common_labels` to supporting resources

## Variables & for_each
- ALWAYS use `map(object)` with `for_each` — NEVER `list`
- Even singleton resources (e.g., VPC) use `for_each` with a single-entry map
- Cross-resource linking: use a key field (e.g., `vpc_key`) to reference via map key
- Use `optional()` with defaults in variable type definitions
- Add `validation {}` blocks to all variables with constrained values (enums, CIDRs, formats)

## Labels
- All resources that support labels receive `labels = var.labels` (or `user_labels` / `resource_labels`)
- Pass `labels = module.naming.common_labels` from layer → module
- Standard labels: client, product, environment, region, managed_by=terraform, layer
- Note: `google_compute_network` does NOT support labels in Google Provider v7+

## Sensitive Outputs
- Mark `sensitive = true` on outputs that contain IPs, endpoints, or connection strings
- Examples: `cluster_endpoints`, `cluster_ca_certificates`, `sql_private_ips`, `sql_connection_names`

## Lifecycle & Reliability
- Use `precondition` blocks for cross-resource dependencies (e.g., GKE requires secondary ranges)
- Use `postcondition` blocks to assert invariants after apply (e.g., no public IP on SQL)
- `prevent_destroy` must be a literal boolean in lifecycle blocks — cannot use variables
- Add `prevent_destroy = false` with a comment in dev; change to `true` for production code

## State Management
- Each layer has its own state file (layer-based isolation)
- Backend prefix is dynamic: `terraform init -backend-config="prefix=CLIENT/ENV/LAYER"`
- GCS bucket: `terraform-states-gcs`
- NEVER hardcode prefix in `backend.tf`

## Validation
- Run `terraform validate` after any code change
- Run `terraform test` to run `.tftest.hcl` files (Terraform 1.6+ native testing)
- Run `terraform fmt -check` to verify formatting
- Run `terraform plan` before apply — review the plan output carefully

## Design Docs
- Before modifying a layer, read its design doc in `docs/plans/`
- Networking: `docs/plans/2026-03-01-bootstrap-networking-design-v2.md`
- Database: `docs/plans/2026-03-02-data-layer-design.md`
- Compute: `docs/plans/2026-03-02-compute-layer-design.md`
- Automation: `docs/plans/2026-03-04-automation-cicd-design.md`
- Identity: `docs/plans/2026-03-08-identity-ingress-design.md`
- App Deployment: `docs/plans/2026-03-09-app-deployment-design.md`
- Gold Standard Hardening: `docs/plans/2026-03-14-gold-standard-hardening-design.md`
- Module Track Decision: `docs/plans/2026-03-15-module-decision-framework.md`
