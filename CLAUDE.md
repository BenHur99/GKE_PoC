# GKE PoC - Claude Code Project Instructions

## About This Project

Production-ready, multi-tenant IaC product for GKE on GCP.
Product name: **GOB** (Google Online Boutique).
Client: **orel**. GCP Project: `orel-bh-sandbox`. Region: `europe-west1`.
Budget: $70/month using ephemeral infrastructure (create morning, destroy evening).

### Owner Context

The owner is a Senior DevOps Tech Lead with 6+ years in Azure/AWS, new to GCP.
This project is a learning exercise - **always explain GCP internals and the "why" behind decisions**.
Communicate in **Hebrew** unless asked otherwise.

## Architecture

### Single Codebase, Multi-Client

One set of `.tf` files per layer under `gob/`. Client/env-specific configuration lives in
`gob/{layer}/tfvars/{client}/{env}.tfvars`. New client = new tfvars folder, no code duplication.
The top-level directory is named after the product (`gob/`).

### Per-Resource Modules

Each Terraform module wraps a single GCP resource (or tightly-coupled pair).
Modules are simple wrappers - they receive a pre-computed `name` variable from the caller.
The layer's `main.tf` orchestrates modules with `for_each` and constructs names using `naming_prefix`.

### Naming Convention

**Format:** `{client}-{product}-{env}-{region_short}-{resource_type}-{name}`
**Example:** `orel-gob-dev-euw1-vpc-main`

Region mapping: `europe-west1` = `euw1`

### Layer-Based State Isolation

Each infrastructure layer has its own Terraform state file (Terragrunt-like, pure Terraform).
Layers reference each other via `terraform_remote_state`.
Backend prefix is **dynamic** - set via `terraform init -backend-config="prefix=CLIENT/ENV/LAYER"`.

### File Structure per Layer

Every layer has: `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `data.tf`, `providers.tf`, `backend.tf`, `versions.tf`
Plus `tfvars/{client}/{env}.tfvars` for each client/environment combination.

### File Structure per Module

Each module has: `main.tf`, `variables.tf`, `outputs.tf`
Single `main.tf` contains all resources. No splitting by resource type.

## Directory Structure

```
GKE_PoC/
├── gob/                             # Product layers (named after product)
│   ├── networking/                  # Layer 1
│   │   ├── main.tf                  # Module calls with for_each
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── locals.tf
│   │   ├── data.tf
│   │   ├── providers.tf
│   │   ├── backend.tf               # Dynamic - no hardcoded prefix
│   │   ├── versions.tf
│   │   └── tfvars/
│   │       └── orel/
│   │           └── dev.tfvars       # orel dev configuration
│   ├── database/                    # Layer 2
│   │   ├── main.tf                  # Module calls with for_each
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── locals.tf
│   │   ├── data.tf                  # terraform_remote_state from networking
│   │   ├── providers.tf
│   │   ├── backend.tf               # Dynamic - no hardcoded prefix
│   │   ├── versions.tf
│   │   └── tfvars/
│   │       └── orel/
│   │           └── dev.tfvars       # orel dev configuration
│   ├── compute/                     # Layer 3
│   │   ├── main.tf                  # Module calls with for_each
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── locals.tf
│   │   ├── data.tf                  # terraform_remote_state from networking
│   │   ├── providers.tf
│   │   ├── backend.tf               # Dynamic - no hardcoded prefix
│   │   ├── versions.tf
│   │   └── tfvars/
│   │       └── orel/
│   │           └── dev.tfvars       # orel dev configuration
│   ├── identity/                    # Layer 5
│   │   ├── main.tf                  # Workload Identity bindings (KSA → GSA)
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── locals.tf
│   │   ├── data.tf                  # terraform_remote_state from database
│   │   ├── providers.tf
│   │   ├── backend.tf               # Dynamic - no hardcoded prefix
│   │   ├── versions.tf
│   │   └── tfvars/
│   │       └── orel/
│   │           └── dev.tfvars       # orel dev configuration
│   └── automation/                  # Layer 4
│       ├── main.tf                  # WIF pools, service accounts, IAM bindings
│       ├── variables.tf
│       ├── outputs.tf
│       ├── locals.tf
│       ├── data.tf                  # Independent (no remote_state)
│       ├── providers.tf
│       ├── backend.tf               # Dynamic - no hardcoded prefix
│       ├── versions.tf
│       └── tfvars/
│           └── orel/
│               └── dev.tfvars       # orel dev configuration
├── modules/
│   ├── vpc/                         # google_compute_network
│   ├── subnet/                      # google_compute_subnetwork
│   ├── firewall_rule/               # google_compute_firewall
│   ├── cloud_nat/                   # google_compute_router + google_compute_router_nat
│   ├── psa/                         # google_compute_global_address + google_service_networking_connection
│   ├── project_api/                 # google_project_service
│   ├── cloud_sql/                   # google_sql_database_instance + google_sql_database
│   ├── service_account/             # google_service_account + google_project_iam_member
│   ├── gke_cluster/                 # google_container_cluster
│   ├── gke_node_pool/               # google_container_node_pool
│   ├── wif_pool/                    # google_iam_workload_identity_pool + provider
│   ├── static_ip/                   # google_compute_address
│   └── wi_binding/                  # google_service_account_iam_member (KSA↔GSA)
├── .github/
│   └── workflows/
│       └── terraform.yml            # Unified workflow (plan/apply/destroy with smart dependency resolution)
└── docs/
    ├── plans/                       # Design docs
```

## Tech Stack

- Terraform >= 1.6 (currently v1.14.6 installed)
- Google Provider >= 6.0 (currently v7.22.0)
- GCS Backend: bucket `terraform-states-gcs`
- State key pattern: `{client}/{env}/{layer}` (set via `-backend-config`)

## How to Run

**Run all commands from the project root:** `C:\Users\user\Desktop\GKE-PoC\GKE_PoC`

### Git Bash

```bash
# --- Networking Layer ---
terraform -chdir=gob/networking init -backend-config="prefix=orel/dev/networking"
terraform -chdir=gob/networking validate
terraform -chdir=gob/networking plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/networking apply -var-file=tfvars/orel/dev.tfvars

# --- Database Layer (requires networking to be applied first) ---
terraform -chdir=gob/database init -backend-config="prefix=orel/dev/database"
terraform -chdir=gob/database validate
terraform -chdir=gob/database plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/database apply -var-file=tfvars/orel/dev.tfvars

# --- Compute Layer (requires networking to be applied first) ---
terraform -chdir=gob/compute init -backend-config="prefix=orel/dev/compute"
terraform -chdir=gob/compute validate
terraform -chdir=gob/compute plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/compute apply -var-file=tfvars/orel/dev.tfvars

# --- Identity Layer (requires database to be applied first) ---
terraform -chdir=gob/identity init -backend-config="prefix=orel/dev/identity"
terraform -chdir=gob/identity validate
terraform -chdir=gob/identity plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/identity apply -var-file=tfvars/orel/dev.tfvars

# --- Automation Layer (one-time manual apply for WIF + CI/CD SA) ---
terraform -chdir=gob/automation init -backend-config="prefix=orel/dev/automation"
terraform -chdir=gob/automation validate
terraform -chdir=gob/automation plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/automation apply -var-file=tfvars/orel/dev.tfvars

# --- Destroy (reverse order!) ---
terraform -chdir=gob/identity destroy -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/compute destroy -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/database destroy -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/networking destroy -var-file=tfvars/orel/dev.tfvars
```

### PowerShell - IMPORTANT: single quotes around flags with slashes

```powershell
terraform -chdir=gob/networking init '-backend-config=prefix=orel/dev/networking'
terraform -chdir=gob/networking plan '-var-file=tfvars/orel/dev.tfvars'
terraform -chdir=gob/database init '-backend-config=prefix=orel/dev/database'
terraform -chdir=gob/database plan '-var-file=tfvars/orel/dev.tfvars'
terraform -chdir=gob/compute init '-backend-config=prefix=orel/dev/compute'
terraform -chdir=gob/compute plan '-var-file=tfvars/orel/dev.tfvars'
terraform -chdir=gob/identity init '-backend-config=prefix=orel/dev/identity'
terraform -chdir=gob/identity plan '-var-file=tfvars/orel/dev.tfvars'
terraform -chdir=gob/automation init '-backend-config=prefix=orel/dev/automation'
terraform -chdir=gob/automation plan '-var-file=tfvars/orel/dev.tfvars'
```

### Switch client/env (re-init)

```bash
terraform -chdir=gob/networking init -reconfigure -backend-config="prefix=OTHER_CLIENT/OTHER_ENV/networking"
terraform -chdir=gob/database init -reconfigure -backend-config="prefix=OTHER_CLIENT/OTHER_ENV/database"
terraform -chdir=gob/compute init -reconfigure -backend-config="prefix=OTHER_CLIENT/OTHER_ENV/compute"
terraform -chdir=gob/identity init -reconfigure -backend-config="prefix=OTHER_CLIENT/OTHER_ENV/identity"
terraform -chdir=gob/automation init -reconfigure -backend-config="prefix=OTHER_CLIENT/OTHER_ENV/automation"
```

## Coding Conventions

- All variables that represent collections use `map(object)` with `for_each` (never `list`)
- Even singleton resources (VPC) use `for_each` with a single-entry map for consistency
- Resources referencing other resources use a `vpc_key` field to link via the map key
- `.tfvars` files under `gob/*/tfvars/` are tracked in git (non-secret configuration)
- Secrets go in environment variables or Secret Manager, never in tfvars
- Use `optional()` with defaults in variable type definitions
- Commit messages follow conventional commits: `feat()`, `fix()`, `refactor()`, `docs()`, `chore()`

## 7-Stage Roadmap

1. **Bootstrap & Networking** - code ready, validated, NOT yet applied
2. **Data Layer** - code ready, validated, NOT yet applied
3. **Compute Layer** - code ready, validated, NOT yet applied
4. **Automation & CI/CD** - APPLIED
5. **Identity & Ingress** - CURRENT (code ready, validated, NOT yet applied)
6. Application Deployment - Online Boutique + Cloud SQL Proxy sidecar
7. Monitoring & Polish - Cloud Monitoring, optimization, resilience testing

## Current Status

### Stage 1: Networking - CODE READY, NOT APPLIED

**What's done:**
- 7 per-resource modules (vpc, subnet, firewall_rule, cloud_nat, psa, project_api, static_ip)
- Layer code at `gob/networking/` with dynamic backend
- Client config at `gob/networking/tfvars/orel/dev.tfvars`
- `terraform init` successful, `terraform validate` successful, `terraform plan` = 16 resources

**Networking resources (16 total):**
| Resource | Name |
|----------|------|
| VPC | orel-gob-dev-euw1-vpc-main |
| Subnet (GKE) | orel-gob-dev-euw1-subnet-gke (10.0.0.0/20) |
| Subnet (Proxy) | orel-gob-dev-euw1-subnet-proxy (10.0.16.0/23) |
| Secondary: Pods | orel-gob-dev-euw1-subnet-gke-pods (10.4.0.0/14) |
| Secondary: Services | orel-gob-dev-euw1-subnet-gke-services (10.8.0.0/20) |
| FW deny-all | orel-gob-dev-euw1-fw-deny-all-ingress |
| FW IAP SSH | orel-gob-dev-euw1-fw-allow-iap-ssh |
| FW Health Checks | orel-gob-dev-euw1-fw-allow-health-checks |
| FW Proxy->Backend | orel-gob-dev-euw1-fw-allow-proxy-to-backends |
| Cloud Router | orel-gob-dev-euw1-main-router |
| Cloud NAT | orel-gob-dev-euw1-main-nat |
| PSA Allocation | orel-gob-dev-euw1-psa-google-managed (10.16.0.0/16) |
| PSA Connection | servicenetworking.googleapis.com peering |
| Static IP | orel-gob-dev-euw1-ip-ingress (Regional External, STANDARD tier) |
| APIs | compute, container, servicenetworking, sqladmin |

### Stage 2: Data Layer - CODE READY, NOT APPLIED

**What's done:**
- 2 new per-resource modules (cloud_sql, service_account)
- Layer code at `gob/database/` with dynamic backend
- Client config at `gob/database/tfvars/orel/dev.tfvars`
- `terraform validate` successful
- Reads networking outputs via `terraform_remote_state`
- Design doc: `docs/plans/2026-03-02-data-layer-design.md`

**Database resources (~5 total):**
| Resource | Name |
|----------|------|
| Cloud SQL Instance | orel-gob-dev-euw1-sql-main (PostgreSQL 15, db-f1-micro) |
| SQL Database | boutique |
| Service Account | orel-gob-dev-euw1-sa-btq-sql |
| IAM Binding | roles/cloudsql.client → GSA |
| API | sqladmin.googleapis.com |

### Stage 3: Compute Layer - CODE READY, NOT APPLIED

**What's done:**
- 2 new per-resource modules (gke_cluster, gke_node_pool)
- Layer code at `gob/compute/` with dynamic backend
- Client config at `gob/compute/tfvars/orel/dev.tfvars`
- `terraform init` successful, `terraform validate` successful
- Reads networking outputs via `terraform_remote_state`
- Design doc: `docs/plans/2026-03-02-compute-layer-design.md`

**Compute resources (~3 total):**
| Resource | Name |
|----------|------|
| GKE Cluster | orel-gob-dev-euw1-gke-main (Zonal europe-west1-b, Private nodes, WI enabled) |
| Node Pool | orel-gob-dev-euw1-gke-main-spot (Spot e2-medium, autoscaling 1-3) |
| API | container.googleapis.com |

**What's next:**
1. Configure GitHub Secrets (WIF_PROVIDER, SERVICE_ACCOUNT, GCP_PROJECT_ID)
2. Push to GitHub and use workflows to deploy all layers (networking → database → compute → identity)
3. Verify in GCP Console (checklists below)
4. Start Stage 6: Application Deployment

### Stage 4: Automation & CI/CD - APPLIED

**What's done:**
- 1 new per-resource module (wif_pool)
- Layer code at `gob/automation/` with dynamic backend
- Client config at `gob/automation/tfvars/orel/dev.tfvars`
- `terraform validate` successful, `terraform apply` successful
- Unified GitHub Actions workflow: `terraform.yml`
- Design doc: `docs/plans/2026-03-04-automation-cicd-design.md`
- Implementation plan: `docs/plans/2026-03-04-automation-cicd-implementation.md`

**Automation resources (~10 total):**
| Resource | Name |
|----------|------|
| WIF Pool | orel-gob-dev-euw1-wip-github |
| WIF Provider | orel-gob-dev-euw1-wipp-github-actions |
| CI/CD Service Account | orel-gob-dev-euw1-sa-cicd |
| IAM Binding | roles/editor → GSA |
| IAM Binding | roles/servicenetworking.networksAdmin → GSA |
| IAM Binding | roles/compute.networkAdmin → Service Networking Agent |
| SA IAM Binding | roles/iam.workloadIdentityUser → GitHub principal |
| APIs | iam, iamcredentials, sts, cloudresourcemanager |

**GitHub Actions Workflow (`terraform.yml`):**
| Feature | Details |
|---------|----------|
| Trigger | workflow_dispatch |
| Actions | plan, apply, destroy |
| Layer Selection | Boolean checkboxes per layer (networking, database, compute, identity) |
| Dependency Resolution | Auto-adds required/dependent layers with visible warnings |
| Fail-Fast | If a layer fails, subsequent layers are skipped |
| Apply Order | networking → database → compute → identity |
| Destroy Order | identity → compute → database → networking |

**GitHub Secrets (after automation apply):**
| Secret | Value |
|--------|-------|
| `GCP_PROJECT_ID` | `orel-bh-sandbox` |
| `WIF_PROVIDER` | `terraform output wif_provider_names` |
| `WIF_SERVICE_ACCOUNT` | `terraform output service_account_emails` |

### Stage 5: Identity & Ingress - CODE READY, NOT APPLIED

**What's done:**
- 2 new per-resource modules (static_ip, wi_binding)
- Static IP added to `gob/networking/` layer (+1 resource)
- New layer code at `gob/identity/` with dynamic backend
- Client config at `gob/identity/tfvars/orel/dev.tfvars`
- `terraform validate` successful
- Reads database outputs via `terraform_remote_state`
- Workflow updated with identity layer (apply/destroy/dependency resolution)
- Design doc: `docs/plans/2026-03-08-identity-ingress-design.md`

**Identity resources (1 total):**
| Resource | Name |
|----------|------|
| WI Binding | KSA `boutique/boutique-sql-proxy` → GSA `orel-gob-dev-euw1-sa-btq-sql` |

**Networking addition (+1, now 16 total):**
| Resource | Name |
|----------|------|
| Static IP | orel-gob-dev-euw1-ip-ingress (Regional External, STANDARD tier) |

### GCP Console Verification Checklist - Networking (after apply):
1. **VPC Networks** - `orel-gob-dev-euw1-vpc-main` exists, Regional routing, no auto subnets
2. **Subnets** - GKE subnet with secondary ranges, proxy subnet with REGIONAL_MANAGED_PROXY
3. **Firewall** - 4 rules with correct priorities and sources
4. **Cloud NAT** - NAT in europe-west1 with auto IPs
5. **PSA** - Allocated range 10.16.0.0/16 peered to servicenetworking
6. **Static IP** - `orel-gob-dev-euw1-ip-ingress` exists, Regional, External, STANDARD tier
7. **APIs** - 4 APIs enabled

### GCP Console Verification Checklist - Database (after apply):
1. **SQL > Instances** - `orel-gob-dev-euw1-sql-main` exists, PostgreSQL 15, db-f1-micro
2. **SQL > Connections** - Private IP from 10.16.x.x range, NO Public IP
3. **SQL > Databases** - `boutique` database exists
4. **SQL > Flags** - `cloudsql.iam_authentication = on`
5. **IAM > Service Accounts** - `orel-gob-dev-euw1-sa-btq-sql@orel-bh-sandbox.iam.gserviceaccount.com`
6. **IAM > Permissions** - GSA has `roles/cloudsql.client`

### GCP Console Verification Checklist - Compute (after apply):
1. **Kubernetes Engine > Clusters** — `orel-gob-dev-euw1-gke-main` exists, Zonal (europe-west1-b), Standard mode
2. **Cluster > Networking** — VPC-native, Pod range 10.4.0.0/14, Service range 10.8.0.0/20, Private cluster (nodes private, endpoint public)
3. **Cluster > Security** — Workload Identity enabled, pool `orel-bh-sandbox.svc.id.goog`
4. **Cluster > Nodes** — Pool `orel-gob-dev-euw1-gke-main-spot`, e2-medium, Spot, autoscaling 1-3, auto-repair, auto-upgrade
5. **Master Authorized Networks** — configured (0.0.0.0/0 in dev)

### GCP Console Verification Checklist - Automation (after apply):
1. **IAM > Workload Identity Pools** - `orel-gob-dev-euw1-wip-github` exists with OIDC provider
2. **WIF Provider** - Issuer: `https://token.actions.githubusercontent.com`, Attribute condition set
3. **IAM > Service Accounts** - `orel-gob-dev-euw1-sa-cicd@orel-bh-sandbox.iam.gserviceaccount.com`
4. **IAM > Permissions** - GSA has `roles/editor` and `roles/servicenetworking.networksAdmin`
5. **GitHub Actions** - Run workflow with `plan` action to verify WIF auth works

### GCP Console Verification Checklist - Identity (after apply):
1. **IAM > Service Accounts > orel-gob-dev-euw1-sa-btq-sql > Permissions** — `roles/iam.workloadIdentityUser` bound to `serviceAccount:orel-bh-sandbox.svc.id.goog[boutique/boutique-sql-proxy]`

### GitHub Actions Verification Checklist (after secrets configured):
1. **Plan all** - Run `terraform.yml` with action=plan, all layers checked → all 4 layers plan successfully
2. **Apply all** - Run `terraform.yml` with action=apply, all layers checked → all layers created
3. **Destroy all** - Run `terraform.yml` with action=destroy, all layers checked → all layers destroyed in reverse order
4. **Single layer test** - Run with only identity checked → resolve job auto-adds database + networking
5. **Fail-fast test** - If networking fails, database, compute, and identity are skipped
6. **Dependency visibility** - Check resolve job logs and Step Summary for auto-added layers

## Design Documents

- `docs/plans/2026-03-01-bootstrap-networking-design-v2.md` - Networking design (approved)
- `docs/plans/2026-03-02-data-layer-design.md` - Data Layer design and implementation plan
- `docs/plans/2026-03-02-compute-layer-design.md` - Compute Layer design document
- `docs/plans/2026-03-02-compute-layer-implementation.md` - Compute Layer implementation plan
- `docs/plans/2026-03-04-automation-cicd-design.md` - Automation & CI/CD design document
- `docs/plans/2026-03-04-automation-cicd-implementation.md` - Automation & CI/CD implementation plan
- `docs/plans/2026-03-08-identity-ingress-design.md` - Identity & Ingress design document