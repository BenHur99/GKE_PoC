# GKE PoC - Claude Code Project Instructions

## About This Project

Production-ready, multi-tenant IaC product for GKE on GCP.
Product name: **GOB** (Google Online Boutique).
Client: **Sela**. GCP Project: `orel-bh-sandbox`. Region: `europe-west1`.
Budget: $70/month using ephemeral infrastructure (create morning, destroy evening).

### Owner Context

The owner is a Senior DevOps Tech Lead with 6+ years in Azure/AWS, new to GCP.
This project is a learning exercise - **always explain GCP internals and the "why" behind decisions**.
Communicate in **Hebrew** unless asked otherwise.

## Architecture

### Per-Resource Modules

Each Terraform module wraps a single GCP resource (or tightly-coupled pair).
Modules are simple wrappers - they receive a pre-computed `name` variable from the caller.
The layer's `main.tf` orchestrates modules with `for_each` and constructs names using `naming_prefix`.

### Naming Convention

**Format:** `{client}-{product}-{env}-{region_short}-{resource_type}-{name}`
**Example:** `sela-gob-dev-euw1-vpc-main`

Region mapping: `europe-west1` = `euw1`

### Layer-Based State Isolation

Each infrastructure layer has its own Terraform state file (Terragrunt-like, pure Terraform).
Layers reference each other via `terraform_remote_state`.
Layer folders do NOT have number prefixes (just `networking/`, not `1-networking/`).

### File Structure per Layer

Every layer (root module) has the FULL set of manifests:
`main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `data.tf`, `providers.tf`, `backend.tf`, `versions.tf`, `<layer>.auto.tfvars`

### File Structure per Module

Each module has: `main.tf`, `variables.tf`, `outputs.tf`
Single `main.tf` contains all resources. No splitting by resource type.

## Directory Structure

```
GKE_PoC/
├── clients/sela/dev/
│   ├── networking/          # Layer 1 - state: sela/dev/networking
│   ├── database/            # Layer 2 (future)
│   ├── compute/             # Layer 3 (future)
│   └── identity/            # Layer 4 (future)
├── modules/
│   ├── vpc/                 # google_compute_network
│   ├── subnet/              # google_compute_subnetwork
│   ├── firewall_rule/       # google_compute_firewall
│   ├── cloud_nat/           # google_compute_router + google_compute_router_nat
│   ├── psa/                 # google_compute_global_address + google_service_networking_connection
│   └── project_api/         # google_project_service
└── docs/plans/              # Design docs and implementation plans
```

## Tech Stack

- Terraform >= 1.6 (currently v1.14.6 installed)
- Google Provider >= 6.0 (currently v7.21.0)
- GCS Backend: bucket `terraform-states-gcs`
- State key pattern: `{client}/{env}/{layer}`

## Coding Conventions

- All variables that represent collections use `map(object)` with `for_each` (never `list`)
- Even singleton resources (VPC) use `for_each` with a single-entry map for consistency
- Resources referencing other resources use a `vpc_key` field to link via the map key
- `.auto.tfvars` files are tracked in git (non-secret configuration)
- Regular `.tfvars` files are gitignored (may contain secrets)
- Use `optional()` with defaults in variable type definitions
- Commit messages follow conventional commits: `feat()`, `fix()`, `refactor()`, `docs()`, `chore()`

## 7-Stage Roadmap

1. **Bootstrap & Networking** - CURRENT (code done, validated, NOT yet applied)
2. Data Layer - Cloud SQL (PostgreSQL) with Private IP and IAM Auth
3. Compute Layer - GKE Standard with Spot Instances and Autoscaling
4. Identity & Ingress - Workload Identity and Regional ALB (NEGs)
5. Application Deployment - Online Boutique + Cloud SQL Proxy sidecar
6. CI/CD - GitHub Actions with Workload Identity Federation (WIF)
7. Monitoring & Polish - Cloud Monitoring, optimization, resilience testing

## Current Status

### Stage 1: Networking - CODE COMPLETE, NOT APPLIED

**What's done:**
- 6 per-resource modules created and reviewed (vpc, subnet, firewall_rule, cloud_nat, psa, project_api)
- Client layer (`clients/sela/dev/networking/`) with 9 files
- `terraform init` successful (GCS backend connected)
- `terraform validate` successful
- `terraform plan` successful - **15 resources to create**
- Design doc v2: `docs/plans/2026-03-01-bootstrap-networking-design-v2.md`

**What's next:**
- Run `terraform apply` in `clients/sela/dev/networking/`
- Verify in GCP Console (checklist in design doc)
- Then start Stage 2: Data Layer

### Resources that will be created (15 total):
| Resource | Name |
|----------|------|
| VPC | sela-gob-dev-euw1-vpc-main |
| Subnet (GKE) | sela-gob-dev-euw1-subnet-gke (10.0.0.0/20) |
| Subnet (Proxy) | sela-gob-dev-euw1-subnet-proxy (10.0.16.0/23) |
| Secondary: Pods | sela-gob-dev-euw1-subnet-gke-pods (10.4.0.0/14) |
| Secondary: Services | sela-gob-dev-euw1-subnet-gke-services (10.8.0.0/20) |
| FW deny-all | sela-gob-dev-euw1-fw-deny-all-ingress |
| FW IAP SSH | sela-gob-dev-euw1-fw-allow-iap-ssh |
| FW Health Checks | sela-gob-dev-euw1-fw-allow-health-checks |
| FW Proxy->Backend | sela-gob-dev-euw1-fw-allow-proxy-to-backends |
| Cloud Router | sela-gob-dev-euw1-main-router |
| Cloud NAT | sela-gob-dev-euw1-main-nat |
| PSA Allocation | sela-gob-dev-euw1-psa-google-managed (10.16.0.0/16) |
| PSA Connection | servicenetworking.googleapis.com peering |
| APIs | compute, container, servicenetworking, sqladmin |

### GCP Console Verification Checklist (after apply):
1. **VPC Networks** - `sela-gob-dev-euw1-vpc-main` exists, Regional routing, no auto subnets
2. **Subnets** - GKE subnet with secondary ranges, proxy subnet with REGIONAL_MANAGED_PROXY
3. **Firewall** - 4 rules with correct priorities and sources
4. **Cloud NAT** - NAT in europe-west1 with auto IPs
5. **PSA** - Allocated range 10.16.0.0/16 peered to servicenetworking
6. **APIs** - 4 APIs enabled

## Design Documents

- `docs/plans/2026-03-01-bootstrap-networking-design-v2.md` - Current approved design
- `docs/plans/2026-03-01-bootstrap-networking-design.md` - Superseded v1 (historical)
- `docs/plans/2026-03-01-bootstrap-networking-plan.md` - Superseded v1 plan (historical)
