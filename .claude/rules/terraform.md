---
paths:
  - "gob/**/*"
  - "modules/**/*"
---

# Terraform Conventions

## Module Structure
- Each module wraps a single GCP resource (or tightly-coupled pair like router+NAT)
- Module files: `main.tf`, `variables.tf`, `outputs.tf` — nothing else
- Single `main.tf` contains all resources — no splitting by resource type
- Modules are simple wrappers — they receive a pre-computed `name` from the caller

## Layer Structure
- Layer files: `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `data.tf`, `providers.tf`, `backend.tf`, `versions.tf`
- Client config: `tfvars/{client}/{env}.tfvars` per layer
- Layer `main.tf` orchestrates modules with `for_each` and constructs names using `naming_prefix`
- Cross-layer data: use `terraform_remote_state` in `data.tf`

## Variables & for_each
- ALWAYS use `map(object)` with `for_each` — NEVER `list`
- Even singleton resources (e.g., VPC) use `for_each` with a single-entry map
- Cross-resource linking: use a key field (e.g., `vpc_key`) to reference via map key
- Use `optional()` with defaults in variable type definitions

## State Management
- Each layer has its own state file (layer-based isolation)
- Backend prefix is dynamic: `terraform init -backend-config="prefix=CLIENT/ENV/LAYER"`
- GCS bucket: `terraform-states-gcs`
- NEVER hardcode prefix in `backend.tf`

## Validation
- Run `terraform validate` after any code change
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
