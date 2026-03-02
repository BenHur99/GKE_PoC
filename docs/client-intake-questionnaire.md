# Architectural Decision Questionnaire

**Purpose:** Questions to ask before building a Terraform project for a client.
These decisions determine the architecture, module strategy, and patterns used.

**Last Updated:** 2026-03-02

---

## Question 1: Multi-Client Support

**Do you need to support multiple clients/tenants from the same codebase?**

| Answer | Architecture Impact |
|--------|-------------------|
| Yes, multiple clients | Shared code + tfvars per client (`gob/{layer}/tfvars/{client}/{env}.tfvars`) |
| No, single client | Can still use tfvars pattern (future-proof) or simpler flat structure |

**Recommendation:** Always use tfvars pattern - zero overhead, maximum flexibility.

---

## Question 2: Code Duplication Strategy

**How should environments (dev/staging/prod) differ?**

| Answer | Architecture Impact |
|--------|-------------------|
| Same code, different config | Shared .tf files + tfvars per env (recommended) |
| Different resources per env | Conditional logic or separate layer sets per env |
| Completely different | Separate codebases (anti-pattern for most cases) |

---

## Question 3: Community vs Custom Modules

**Should we use GCP community modules (`terraform-google-modules/*`) or build custom?**

| Answer | When to Choose | Trade-off |
|--------|---------------|-----------|
| Community modules | Production delivery, complex resources (GKE, SQL) | Less control, more features, maintained by Google |
| Custom per-resource | Learning, simple wrappers, full control | More code, more maintenance, full understanding |
| Hybrid | Best of both | Community for complex, custom for simple/unique |

**Decision matrix:**

| Resource | Community Module | Custom? |
|----------|-----------------|---------|
| VPC + Subnets + Firewall | `terraform-google-modules/network/google` | Custom if simple needs |
| GKE | `terraform-google-modules/kubernetes-engine/google` | Almost always community |
| Cloud SQL | `terraform-google-modules/sql-db/google` | Almost always community |
| IAM | `terraform-google-modules/iam/google` | Custom for simple bindings |
| Cloud NAT | Part of network module | Custom is fine (simple) |
| PSA | N/A (no community module) | Custom |

---

## Question 4: Module Granularity

**Per-resource modules or per-domain modules?**

| Answer | Example | When |
|--------|---------|------|
| Per-resource | `modules/vpc/`, `modules/subnet/`, `modules/firewall_rule/` | Learning, maximum reuse, fine control |
| Per-domain | `modules/networking/`, `modules/database/` | Production delivery, fewer modules, faster development |
| Hybrid | Per-domain for complex, per-resource for simple | Balanced approach |

**Current project (GOB):** Per-resource (learning exercise).
**Production recommendation:** Per-domain or community modules.

---

## Question 5: State Isolation Strategy

**How should Terraform state be organized?**

| Answer | State Files | When |
|--------|------------|------|
| Per-layer | `{client}/{env}/networking`, `{client}/{env}/database` | Multiple layers with dependencies (recommended) |
| Per-environment | `{client}/{env}/all` | Small projects, few resources |
| Per-resource-group | Fine-grained splits | Very large projects, many teams |

**Recommendation:** Per-layer with `terraform_remote_state` for cross-layer references.

---

## Question 6: Backend Strategy

**How should the Terraform backend be configured?**

| Answer | Config | When |
|--------|--------|------|
| Dynamic (prefix at init) | `backend "gcs" { bucket = "..." }` + `-backend-config="prefix=..."` | Multi-client, multi-env (recommended) |
| Hardcoded | `backend "gcs" { bucket = "...", prefix = "..." }` | Single client, single env |
| Terragrunt | `remote_state { ... }` in terragrunt.hcl | Complex multi-account setups |

**Current project:** Dynamic with GCS bucket `terraform-states-gcs`.

---

## Question 7: Naming Convention Depth

**How detailed should resource names be?**

| Answer | Format | Example |
|--------|--------|---------|
| Full context | `{client}-{product}-{env}-{region_short}-{type}-{name}` | `orel-gob-dev-euw1-vpc-main` |
| Medium | `{product}-{env}-{type}-{name}` | `gob-dev-vpc-main` |
| Minimal | `{env}-{type}-{name}` | `dev-vpc-main` |

**Recommendation:** Full context for multi-client, medium for single-client.

---

## Question 8: Variable Pattern

**How should variables be structured?**

| Answer | Pattern | When |
|--------|---------|------|
| map(object) + for_each | `variable "subnets" { type = map(object({...})) }` | Always (consistency, extensibility) |
| Individual variables | `variable "vpc_name" { type = string }` | Never for collections |
| list(object) | `variable "subnets" { type = list(object({...})) }` | Never (no stable keys for for_each) |

**Recommendation:** Always `map(object)` with `optional()` defaults. Even singletons.

---

## Client Profiles

### Profile A: Enterprise Multi-Tenant
- Multi-client: Yes
- Modules: Community + custom hybrid
- Granularity: Per-domain
- State: Per-layer per client
- Backend: Dynamic
- Naming: Full context
- CI/CD: Per-client pipelines

### Profile B: Single-Client Production
- Multi-client: No (but use tfvars anyway)
- Modules: Community
- Granularity: Per-domain
- State: Per-layer
- Backend: Dynamic or hardcoded
- Naming: Medium
- CI/CD: Single pipeline with env gates

### Profile C: PoC / Learning
- Multi-client: No
- Modules: Custom per-resource (for learning)
- Granularity: Per-resource
- State: Per-layer
- Backend: Dynamic
- Naming: Full context (practice)
- CI/CD: Manual (terraform apply)

**Current project (GOB):** Profile C transitioning to Profile A.
