# Stage 4: Automation & CI/CD - Design Document

**Date:** 2026-03-04
**Status:** Approved
**Author:** Claude Code + orel (Tech Lead)

## Goal

Automate full deployment and teardown of all GOB infrastructure layers via GitHub Actions,
using Workload Identity Federation (WIF) for keyless GCP authentication.

After this stage, the only manual Terraform operation is the one-time apply of the `automation` layer itself.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Auth method | WIF (not JSON key) | Zero-trust, no static secrets, short-lived tokens, audit trail |
| WIF module | `modules/wif_pool/` (Pool+Provider pair) | Consistent with per-resource module pattern (like cloud_nat) |
| CI/CD SA | Reuse `modules/service_account/` | Module already exists, handles GSA + IAM roles |
| SA-to-WIF binding | In layer (`gob/automation/main.tf`) | Binding is orchestration, not module responsibility |
| IAM roles | `roles/editor` + `roles/servicenetworking.networksAdmin` | Fast iteration + PSA requirements |
| Workflow structure | Single workflow (`terraform.yml`) | Dynamic dependencies via a resolve job, opposite ordering for deploy vs destroy |
| Trigger | `workflow_dispatch` only | Manual control, matches ephemeral infra pattern |
| Artifact Registry | Deferred to Stage 5 | YAGNI - not needed until App Deployment |
| Action pinning | SHA-pinned (not tag) | Supply-chain security best practice |

## WIF Token Exchange Flow

```
GitHub Actions Runner
    │
    ├─ 1. OIDC Token: GitHub issues JWT with claims
    │     (repository, ref, workflow, actor, etc.)
    │
    ├─ 2. STS Exchange: Runner sends JWT to GCP STS
    │     endpoint referencing our Pool/Provider
    │
    ├─ 3. Validation: GCP verifies:
    │     - JWT signed by GitHub (OIDC discovery)
    │     - Claims pass attribute_condition
    │     - Provider configured for correct issuer
    │
    ├─ 4. Federated Token: GCP returns temporary STS token
    │
    └─ 5. Impersonation: STS token used to impersonate
          our GSA → gets access_token with GSA's
          permissions (roles/editor)
```

**Why WIF over JSON key:**
- No stored secret - GitHub's JWT is valid for minutes and non-reusable
- `attribute_condition` restricts to specific repository
- Full audit log in GCP Cloud Audit Logs

## New Module: `modules/wif_pool/`

Wraps a tightly-coupled pair (like `cloud_nat` wraps router+nat):
- `google_iam_workload_identity_pool`
- `google_iam_workload_identity_pool_provider`

### Variables

| Variable | Type | Description |
|----------|------|-------------|
| `name` | `string` | Pool name (pre-computed by layer) |
| `project_id` | `string` | GCP project |
| `display_name` | `string` | Human-readable name |
| `provider_id` | `string` | Provider name (pre-computed by layer) |
| `issuer_uri` | `string` | OIDC Issuer URL |
| `attribute_mapping` | `map(string)` | Claim-to-attribute mappings |
| `attribute_condition` | `string` | CEL expression for zero-trust |

### Outputs

| Output | Description |
|--------|-------------|
| `pool_id` | Pool ID |
| `pool_name` | Pool full resource name (for IAM bindings) |
| `provider_id` | Provider ID |
| `provider_name` | Provider full resource name |

## New Layer: `gob/automation/`

### File Structure

```
gob/automation/
├── main.tf          # Module calls + SA-to-WIF binding
├── variables.tf     # Common vars + wif_pools, service_accounts maps
├── outputs.tf       # Pool/Provider IDs, SA email
├── locals.tf        # naming_prefix (same pattern as all layers)
├── data.tf          # Empty (no remote_state dependency)
├── providers.tf     # google provider
├── backend.tf       # GCS dynamic backend
├── versions.tf      # terraform >= 1.6, google >= 6.0
└── tfvars/
    └── orel/
        └── dev.tfvars
```

### Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| WIF Pool | `orel-gob-dev-euw1-wip-github` | Identity pool for GitHub |
| WIF Provider | `orel-gob-dev-euw1-wipp-github-actions` | OIDC provider for GHA |
| CI/CD GSA | `orel-gob-dev-euw1-sa-cicd` | Service account for deployments |
| IAM Binding | `roles/editor` → GSA | Project-level permissions |
| IAM Binding | `roles/iam.workloadIdentityUser` → GitHub principal | Allows impersonation |
| APIs | iam, iamcredentials, sts, cloudresourcemanager | Required GCP APIs |

### Attribute Condition (Zero-Trust)

```cel
assertion.repository_owner == "BenHur99"
```

Combined with the SA IAM binding that restricts to `attribute.repository/BenHur99/GKE_PoC`,
only this specific repository can impersonate the GSA.

### tfvars Configuration

```hcl
wif_pools = {
  github = {
    display_name       = "GitHub Actions Pool"
    provider_id        = "github-actions"
    issuer_uri         = "https://token.actions.githubusercontent.com"
    attribute_condition = "assertion.repository_owner == \"BenHur99\""
    attribute_mapping = {
      "google.subject"             = "assertion.sub"
      "attribute.actor"            = "assertion.actor"
      "attribute.repository"       = "assertion.repository"
      "attribute.repository_owner" = "assertion.repository_owner"
    }
  }
}

service_accounts = {
  cicd = {
    display_name = "CI/CD GitHub Actions"
    description  = "SA for GitHub Actions WIF-based deployment"
    roles        = ["roles/editor", "roles/servicenetworking.networksAdmin"]
    wif_pool_key = "github"
    github_repo  = "BenHur99/GKE_PoC"
  }
}
```

## GitHub Actions Workflow (`terraform.yml`)

### Unified Pipeline Design

Instead of separate deploy/destroy workflows, we use a single `terraform.yml` with smart dependency resolution.

**Trigger:** `workflow_dispatch`

**Inputs:**
| Input | Type | Options | Default |
|-------|------|---------|---------|
| `action` | choice | plan, apply, destroy | plan |
| `layer_networking` | boolean | true/false | false |
| `layer_database`   | boolean | true/false | false |
| `layer_compute`    | boolean | true/false | false |
| `client` | string | - | orel |
| `environment` | string | - | dev |

### Smart Dependency Resolution (`resolve` Job)

Since GHA `needs` are static and users might select only partial layers (e.g., just `compute`), a dedicated first job resolves dependencies:

1. Takes Boolean inputs for each layer.
2. Checks action type (`apply/plan` vs `destroy`).
3. Auto-adds dependencies:
   - For `apply`/`plan`: If `compute` is checked, adds `database` and `networking`.
   - For `destroy`: If `networking` is checked, adds `database` and `compute` (reverse dependency).
4. Outputs boolean flags indicating which layers must actually run.

### Jobs (Execution Flow)

**Apply / Plan Sequence:**
```
networking-apply → database-apply → compute-apply
```
Each job checks `if: needs.resolve.outputs.run_<layer> == 'true' && inputs.action != 'destroy'`.

**Destroy Sequence:**
```
compute-destroy → database-destroy → networking-destroy
```
Each job checks `if: needs.resolve.outputs.run_<layer> == 'true' && inputs.action == 'destroy'`.

### Fail-Fast Behavior
To prevent cascading failures across layers, each dependent layer validates that its predecessor succeeded:
```yaml
if: |
  always() &&
  needs.resolve.outputs.run_database == 'true' &&
  inputs.action != 'destroy' &&
  (needs.networking-apply.result == 'success' || needs.networking-apply.result == 'skipped')
```

The pipeline constructs the state prefix from workflow inputs:

```bash
terraform -chdir=gob/$LAYER init \
  -backend-config="prefix=$CLIENT/$ENV/$LAYER"
```

No hardcoded prefixes anywhere - fully dynamic.

### Required GitHub Secrets

| Secret | Value | Source |
|--------|-------|--------|
| `GCP_PROJECT_ID` | `orel-bh-sandbox` | Known |
| `WIF_PROVIDER` | `projects/PROJECT_NUM/locations/global/workloadIdentityPools/POOL/providers/PROVIDER` | `terraform output` from automation layer |
| `WIF_SERVICE_ACCOUNT` | `orel-gob-dev-euw1-sa-cicd@orel-bh-sandbox.iam.gserviceaccount.com` | `terraform output` from automation layer |

### Security Best Practices

1. **SHA-pinned actions** - All third-party actions pinned to specific commit SHA
2. **Minimal permissions** - `id-token: write` and `contents: read` only
3. **WIF attribute condition** - Restricts to repo owner
4. **SA IAM binding** - Restricts to specific repository
5. **No secrets in code** - All sensitive values in GitHub Secrets

## Production IAM Roles Reference

For production, replace `roles/editor` with least-privilege roles:

| Layer | Required Roles |
|-------|---------------|
| Networking | `roles/compute.networkAdmin`, `roles/compute.securityAdmin`, `roles/servicenetworking.networksAdmin` |
| Database | `roles/cloudsql.admin`, `roles/iam.serviceAccountCreator` |
| Compute | `roles/container.admin`, `roles/iam.serviceAccountUser` |
| All layers | `roles/serviceusage.serviceUsageAdmin` (for API enablement) |

## Deployment Process

1. **One-time manual:** Apply automation layer
   ```bash
   terraform -chdir=gob/automation init -backend-config="prefix=orel/dev/automation"
   terraform -chdir=gob/automation apply -var-file=tfvars/orel/dev.tfvars
   ```
2. **Configure GitHub Secrets** from terraform outputs
3. **From now on:** Use GitHub Actions UI → "Run workflow" → select action + scope

## Updated Roadmap Position

```
1. Networking (done) → 2. Database (done) → 3. Compute (done)
→ 4. Automation & CI/CD (THIS STAGE)
→ 5. Identity & Ingress → 6. App Deployment → 7. Monitoring
```

## Updated Directory Structure

```
GKE_PoC/
├── gob/
│   ├── networking/          # Layer 1
│   ├── database/            # Layer 2
│   ├── compute/             # Layer 3
│   └── automation/          # Layer 4 (NEW)
├── modules/
│   ├── vpc/
│   ├── subnet/
│   ├── firewall_rule/
│   ├── cloud_nat/
│   ├── psa/
│   ├── project_api/
│   ├── cloud_sql/
│   ├── service_account/
│   ├── gke_cluster/
│   ├── gke_node_pool/
│   └── wif_pool/            # NEW
├── .github/
│   └── workflows/
│       └── terraform.yml          # Unified CI/CD config
└── docs/
    └── plans/
        └── 2026-03-04-automation-cicd-design.md  # THIS DOC
```
