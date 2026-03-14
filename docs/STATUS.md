# GOB Project — Roadmap & Status

## 7-Stage Roadmap

1. **Bootstrap & Networking** - code ready, validated, NOT yet applied
2. **Data Layer** - code ready, validated, NOT yet applied
3. **Compute Layer** - code ready, validated, NOT yet applied
4. **Automation & CI/CD** - APPLIED
5. **Identity & Ingress** - MERGED into database layer (WI bindings live in database layer now)
6. **Application Deployment** - CURRENT (code ready, NOT yet applied)
7. Monitoring & Polish - Cloud Monitoring, optimization, resilience testing

---

## Stage 1: Networking — CODE READY, NOT APPLIED

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

---

## Stage 2: Data Layer — CODE READY, NOT APPLIED

**What's done:**
- 2 new per-resource modules (cloud_sql, service_account)
- Layer code at `gob/database/` with dynamic backend
- Client config at `gob/database/tfvars/orel/dev.tfvars`
- `terraform validate` successful
- Reads networking outputs via `terraform_remote_state`
- Design doc: `docs/plans/2026-03-02-data-layer-design.md`

**Database resources (~6 total):**

| Resource | Name |
|----------|------|
| Cloud SQL Instance | orel-gob-dev-euw1-sql-main (PostgreSQL 15, db-f1-micro) |
| SQL Database | boutique |
| Service Account | orel-gob-dev-euw1-sa-btq-sql |
| IAM Binding | roles/cloudsql.client → GSA |
| WI Binding | KSA `boutique/boutique-sql-proxy` → GSA `orel-gob-dev-euw1-sa-btq-sql` |
| API | sqladmin.googleapis.com |

---

## Stage 3: Compute Layer — CODE READY, NOT APPLIED

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

---

## Stage 4: Automation & CI/CD — APPLIED

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
| Layer Selection | Boolean checkboxes per layer (networking, database, compute) |
| Dependency Resolution | Auto-adds required/dependent layers with visible warnings |
| Fail-Fast | If a layer fails, subsequent layers are skipped |
| Apply Order | networking → database → compute |
| Destroy Order | compute → database → networking |

**GitHub Secrets (after automation apply):**

| Secret | Value |
|--------|-------|
| `GCP_PROJECT_ID` | `orel-bh-sandbox` |
| `WIF_PROVIDER` | `terraform output wif_provider_names` |
| `SERVICE_ACCOUNT` | `terraform output service_account_emails` |

---

## Stage 5: Identity & Ingress — MERGED INTO DATABASE LAYER

WI binding (KSA→GSA) merged into `gob/database/` layer. Static IP remains in networking.
The `gob/identity/` layer has been removed. Design doc: `docs/plans/2026-03-08-identity-ingress-design.md`

---

## Stage 6: Application Deployment — CODE READY, NOT APPLIED

**What's done:**
- Custom Helm chart at `helm/online-boutique/`
- Frontend + CartService + Redis deployments
- Cloud SQL Auth Proxy sidecar on cartservice (WI demo)
- Gateway API (gke-l7-regional-external-managed) with Static IP
- HealthCheckPolicy for frontend health checks
- Workflow updated with deploy-app/destroy-app jobs
- Design doc: `docs/plans/2026-03-09-app-deployment-design.md`

**Application resources (11 K8s resources):**

| Resource | Name |
|----------|------|
| Namespace | boutique |
| KSA | boutique-sql-proxy (WI → GSA btq-sql) |
| Deployment | frontend (1 replica, port 8080) |
| Service | frontend (ClusterIP:80, NEG annotation) |
| Deployment | cartservice (1 replica + SQL Proxy sidecar) |
| Service | cartservice (ClusterIP:7070) |
| Deployment | redis-cart (1 replica, port 6379) |
| Service | redis-cart (ClusterIP:6379) |
| Gateway | frontend (gke-l7-regional-external-managed, Static IP) |
| HTTPRoute | frontend (→ frontend:80) |
| HealthCheckPolicy | frontend (HTTP /_healthz:8080) |

---

## GCP Console Verification Checklists

### Networking (after apply):
1. **VPC Networks** - `orel-gob-dev-euw1-vpc-main` exists, Regional routing, no auto subnets
2. **Subnets** - GKE subnet with secondary ranges, proxy subnet with REGIONAL_MANAGED_PROXY
3. **Firewall** - 4 rules with correct priorities and sources
4. **Cloud NAT** - NAT in europe-west1 with auto IPs
5. **PSA** - Allocated range 10.16.0.0/16 peered to servicenetworking
6. **Static IP** - `orel-gob-dev-euw1-ip-ingress` exists, Regional, External, STANDARD tier
7. **APIs** - 4 APIs enabled

### Database (after apply):
1. **SQL > Instances** - `orel-gob-dev-euw1-sql-main` exists, PostgreSQL 15, db-f1-micro
2. **SQL > Connections** - Private IP from 10.16.x.x range, NO Public IP
3. **SQL > Databases** - `boutique` database exists
4. **SQL > Flags** - `cloudsql.iam_authentication = on`
5. **IAM > Service Accounts** - `orel-gob-dev-euw1-sa-btq-sql@orel-bh-sandbox.iam.gserviceaccount.com`
6. **IAM > Permissions** - GSA has `roles/cloudsql.client`
7. **IAM > SA > orel-gob-dev-euw1-sa-btq-sql > Permissions** — `roles/iam.workloadIdentityUser` bound to `serviceAccount:orel-bh-sandbox.svc.id.goog[boutique/boutique-sql-proxy]`

### Compute (after apply):
1. **Kubernetes Engine > Clusters** — `orel-gob-dev-euw1-gke-main` exists, Zonal (europe-west1-b), Standard mode
2. **Cluster > Networking** — VPC-native, Pod range 10.4.0.0/14, Service range 10.8.0.0/20, Private cluster (nodes private, endpoint public)
3. **Cluster > Security** — Workload Identity enabled, pool `orel-bh-sandbox.svc.id.goog`
4. **Cluster > Nodes** — Pool `orel-gob-dev-euw1-gke-main-spot`, e2-medium, Spot, autoscaling 1-3, auto-repair, auto-upgrade
5. **Master Authorized Networks** — configured (0.0.0.0/0 in dev)

### Automation (after apply):
1. **IAM > Workload Identity Pools** - `orel-gob-dev-euw1-wip-github` exists with OIDC provider
2. **WIF Provider** - Issuer: `https://token.actions.githubusercontent.com`, Attribute condition set
3. **IAM > Service Accounts** - `orel-gob-dev-euw1-sa-cicd@orel-bh-sandbox.iam.gserviceaccount.com`
4. **IAM > Permissions** - GSA has `roles/editor`, `roles/servicenetworking.networksAdmin`, and `roles/iam.serviceAccountAdmin`
5. **GitHub Actions** - Run workflow with `plan` action to verify WIF auth works

### GitHub Actions (after secrets configured):
1. **Plan all** - Run `terraform.yml` with action=plan, all layers checked → all 3 layers plan successfully
2. **Apply all** - Run `terraform.yml` with action=apply, all layers checked → all layers created
3. **Destroy all** - Run `terraform.yml` with action=destroy, all layers checked → all layers destroyed in reverse order
4. **Single layer test** - Run with only compute checked → resolve job auto-adds database + networking
5. **Fail-fast test** - If networking fails, database and compute are skipped
6. **Dependency visibility** - Check resolve job logs and Step Summary for auto-added layers

---

## Module Reference (13 modules)

| Module | GCP Resource(s) | Stage |
|--------|-----------------|-------|
| `vpc/` | google_compute_network | 1 |
| `subnet/` | google_compute_subnetwork | 1 |
| `firewall_rule/` | google_compute_firewall | 1 |
| `cloud_nat/` | google_compute_router + google_compute_router_nat | 1 |
| `psa/` | google_compute_global_address + google_service_networking_connection | 1 |
| `project_api/` | google_project_service | 1 |
| `static_ip/` | google_compute_address | 1 |
| `cloud_sql/` | google_sql_database_instance + google_sql_database | 2 |
| `service_account/` | google_service_account + google_project_iam_member | 2 |
| `gke_cluster/` | google_container_cluster | 3 |
| `gke_node_pool/` | google_container_node_pool | 3 |
| `wif_pool/` | google_iam_workload_identity_pool + provider | 4 |
| `wi_binding/` | google_service_account_iam_member (KSA↔GSA) | 5 |

All modules live under `modules/`. Each has: `main.tf`, `variables.tf`, `outputs.tf`.

---

## Design Documents

- `docs/plans/2026-03-01-bootstrap-networking-design-v2.md` - Networking design (approved)
- `docs/plans/2026-03-02-data-layer-design.md` - Data Layer design and implementation plan
- `docs/plans/2026-03-02-compute-layer-design.md` - Compute Layer design document
- `docs/plans/2026-03-02-compute-layer-implementation.md` - Compute Layer implementation plan
- `docs/plans/2026-03-04-automation-cicd-design.md` - Automation & CI/CD design document
- `docs/plans/2026-03-04-automation-cicd-implementation.md` - Automation & CI/CD implementation plan
- `docs/plans/2026-03-08-identity-ingress-design.md` - Identity & Ingress design document
- `docs/plans/2026-03-09-app-deployment-design.md` - Application Deployment design document
- `docs/plans/2026-03-09-app-deployment-implementation.md` - Application Deployment implementation plan
- `docs/plans/2026-03-14-claude-code-refactoring-design.md` - Claude Code configuration refactoring plan
