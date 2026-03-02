# Compute Layer (Stage 3) - Design Document

**Status:** Approved
**Date:** 2026-03-02
**Goal:** Build the Compute Layer — GKE Standard (Zonal) with Private Nodes, Spot-based Node Pool, and Workload Identity enabled, following the per-resource module + layer orchestration pattern.

---

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| GKE Mode | Standard (not Autopilot) | Learning project — Standard exposes all internals (node management, scaling, eviction). Autopilot hides infra. |
| Cluster Type | Zonal (europe-west1-b) | Free management fee ($0 vs $74.40/mo for Regional). Acceptable for dev/learning. |
| Privacy | Private Nodes + Public Endpoint | Nodes have no public IPs (secured). API accessible from internet with Master Authorized Networks. Allows `kubectl` from local machine. |
| Modules | 2 separate (gke_cluster + gke_node_pool) | Follows per-resource module pattern. Cluster and node pool are independently configurable. |
| Machine Type | e2-medium (2 vCPU, 4GB) | Sweet spot for Online Boutique (11 microservices, ~100-200Mi each). ~$10/node/mo Spot. |
| Scope | Cluster + Node Pool only | Workload Identity is enabled at cluster level but KSA↔GSA binding deferred to Stage 4 (Identity & Ingress). |
| Deletion Protection | false | Ephemeral environment — must be destroyable every evening. |

---

## GKE Internals (Learning Notes)

### Standard vs Autopilot
- **Standard:** You manage Node Pools, machine types, scaling, DaemonSets, taints/tolerations. Full control. Pay per node (even if idle).
- **Autopilot:** Google manages everything. Pay per Pod resource request. No node-level access. Production-friendly but hides learning opportunities.

### VPC-native (Alias IP Ranges)
GKE can run in two networking modes:
- **Routes-based (legacy):** Each node gets a VPC route. Not scalable, not recommended.
- **VPC-native (modern):** Uses subnet Secondary Ranges. Pods get IPs from the `pods` range, Services from the `services` range. Enables direct Pod-to-VPC-resource communication (e.g., Pods → Cloud SQL private IP).

Our secondary ranges from Stage 1: `pods` = 10.4.0.0/14 (~260K IPs), `services` = 10.8.0.0/20 (~4K IPs).

### Private Cluster — master_ipv4_cidr_block
In a Private Cluster, the Control Plane gets a private IP in a separate /28 range. Google creates a VPC peering from your network to Google's internal network where the Control Plane runs. `172.16.0.0/28` is a common convention that doesn't conflict with our other ranges (10.x.x.x).

### Spot Instances
- **Preemptible (legacy):** 24-hour max lifetime. Deprecated.
- **Spot (current):** Same 60-90% discount, no 24-hour limit. Google can reclaim anytime. Perfect for ephemeral environments. `auto_repair = true` ensures GKE recreates evicted nodes automatically.

### remove_default_node_pool
GKE requires at least 1 node at cluster creation. The default node pool created during cluster provisioning cannot be fully managed by Terraform. Standard pattern: create with `initial_node_count = 1`, immediately remove with `remove_default_node_pool = true`, then create a separately managed node pool.

### Master Authorized Networks
A whitelist of CIDR blocks allowed to reach the Kubernetes API. In dev: `0.0.0.0/0` (open). In production: specific office/CI IPs only. Implemented as a `dynamic` block since each client has different requirements.

---

## Resource Inventory (~3 resources)

| Resource | Name | Details |
|----------|------|---------|
| API | container.googleapis.com | Already enabled in networking, idempotent re-declaration |
| GKE Cluster | orel-gob-dev-euw1-gke-main | Zonal (europe-west1-b), private nodes, public endpoint, VPC-native, WI enabled |
| Node Pool | orel-gob-dev-euw1-gke-main-spot | Spot e2-medium, autoscaling 1-3, auto-repair, auto-upgrade |

---

## Module Design

### Module 1: `modules/gke_cluster/`

Wraps `google_container_cluster`. Single resource with dynamic blocks for configurable sections.

**Variables:**

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | string | required | Pre-computed cluster name |
| `project_id` | string | required | GCP project ID |
| `location` | string | required | Zone (e.g., europe-west1-b) |
| `network_id` | string | required | VPC self link |
| `subnet_id` | string | required | Subnet self link |
| `pods_secondary_range_name` | string | required | Secondary range name for pods |
| `services_secondary_range_name` | string | required | Secondary range name for services |
| `master_ipv4_cidr_block` | string | `"172.16.0.0/28"` | CIDR for control plane private endpoint |
| `master_authorized_networks` | `map(object({ cidr_block = string }))` | `{}` | CIDRs allowed to access K8s API |
| `release_channel` | string | `"REGULAR"` | GKE release channel |
| `workload_identity_enabled` | bool | `true` | Enable Workload Identity pool |
| `deletion_protection` | bool | `false` | Must be false for ephemeral envs |

**Outputs:** `id`, `name`, `endpoint`, `ca_certificate`, `master_version`

**Key implementation details:**
- `remove_default_node_pool = true` + `initial_node_count = 1`
- `private_cluster_config` with `enable_private_nodes = true`, `enable_private_endpoint = false`
- `ip_allocation_policy` referencing secondary range names
- `workload_identity_config` with project pool
- `dynamic "master_authorized_networks_config"` block — only created when `master_authorized_networks` is non-empty
- Inside the config: `dynamic "cidr_blocks"` iterating over the map

### Module 2: `modules/gke_node_pool/`

Wraps `google_container_node_pool`. Single resource.

**Variables:**

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | string | required | Pre-computed pool name |
| `project_id` | string | required | GCP project ID |
| `location` | string | required | Zone |
| `cluster_name` | string | required | GKE cluster name (dependency) |
| `machine_type` | string | `"e2-medium"` | Node machine type |
| `spot` | bool | `true` | Use Spot instances |
| `min_node_count` | number | `1` | Autoscaling minimum |
| `max_node_count` | number | `3` | Autoscaling maximum |
| `disk_size_gb` | number | `50` | Boot disk size |
| `disk_type` | string | `"pd-standard"` | Boot disk type |
| `auto_repair` | bool | `true` | Auto-repair failed nodes |
| `auto_upgrade` | bool | `true` | Auto-upgrade node versions |
| `oauth_scopes` | list(string) | `["https://www.googleapis.com/auth/cloud-platform"]` | OAuth scopes for nodes |

**Outputs:** `id`, `name`

**Key implementation details:**
- `node_config` with `spot`, `machine_type`, `disk_size_gb`, `disk_type`, `oauth_scopes`
- `node_config.workload_metadata_config.mode = "GKE_METADATA"` (required for Workload Identity on nodes)
- `autoscaling` block with `min_node_count` / `max_node_count`
- `management` block with `auto_repair` / `auto_upgrade`

---

## Layer Design: `gob/compute/`

### File Structure
```
gob/compute/
├── main.tf           # module calls: apis, gke_clusters, node_pools
├── variables.tf      # common vars + gke_clusters + node_pools (map(object))
├── outputs.tf        # cluster endpoints, names, CA certs
├── locals.tf         # naming_prefix (identical to other layers)
├── data.tf           # terraform_remote_state: networking
├── providers.tf      # google provider
├── backend.tf        # gcs backend (dynamic prefix)
├── versions.tf       # terraform >= 1.6, google >= 6.0
└── tfvars/
    └── orel/
        └── dev.tfvars
```

### Variable Definitions (`variables.tf`)

```hcl
# --- Common (identical across all layers) ---
variable "client_name"  { type = string }
variable "product_name" { type = string }
variable "environment"  { type = string }
variable "project_id"   { type = string }
variable "region"        { type = string }

# --- APIs ---
variable "apis" {
  type    = list(string)
  default = []
}

# --- GKE Clusters ---
variable "gke_clusters" {
  type = map(object({
    subnet_key                    = string
    pods_secondary_range_key      = optional(string, "pods")
    services_secondary_range_key  = optional(string, "services")
    zone                          = string
    master_ipv4_cidr_block        = optional(string, "172.16.0.0/28")
    release_channel               = optional(string, "REGULAR")
    workload_identity_enabled     = optional(bool, true)
    deletion_protection           = optional(bool, false)
    master_authorized_networks    = optional(map(object({
      cidr_block = string
    })), {})
  }))
  default = {}
}

# --- Node Pools ---
variable "node_pools" {
  type = map(object({
    cluster_key     = string
    machine_type    = optional(string, "e2-medium")
    spot            = optional(bool, true)
    min_node_count  = optional(number, 1)
    max_node_count  = optional(number, 3)
    disk_size_gb    = optional(number, 50)
    disk_type       = optional(string, "pd-standard")
    auto_repair     = optional(bool, true)
    auto_upgrade    = optional(bool, true)
    oauth_scopes    = optional(list(string), ["https://www.googleapis.com/auth/cloud-platform"])
  }))
  default = {}
}
```

### Layer Orchestration (`main.tf`)

```hcl
module "apis" {
  for_each   = toset(var.apis)
  source     = "../../modules/project_api"
  project_id = var.project_id
  api        = each.value
}

module "gke_clusters" {
  for_each = var.gke_clusters
  source   = "../../modules/gke_cluster"

  name       = "${local.naming_prefix}-gke-${each.key}"
  project_id = var.project_id
  location   = each.value.zone

  network_id                    = data.terraform_remote_state.networking.outputs.vpc_self_links["main"]
  subnet_id                     = data.terraform_remote_state.networking.outputs.subnet_self_links[each.value.subnet_key]
  pods_secondary_range_name     = data.terraform_remote_state.networking.outputs.subnet_secondary_range_names[each.value.subnet_key][each.value.pods_secondary_range_key]
  services_secondary_range_name = data.terraform_remote_state.networking.outputs.subnet_secondary_range_names[each.value.subnet_key][each.value.services_secondary_range_key]

  master_ipv4_cidr_block     = each.value.master_ipv4_cidr_block
  release_channel            = each.value.release_channel
  workload_identity_enabled  = each.value.workload_identity_enabled
  deletion_protection        = each.value.deletion_protection
  master_authorized_networks = each.value.master_authorized_networks

  depends_on = [module.apis]
}

module "node_pools" {
  for_each = var.node_pools
  source   = "../../modules/gke_node_pool"

  name         = "${local.naming_prefix}-gke-${each.value.cluster_key}-${each.key}"
  project_id   = var.project_id
  location     = var.gke_clusters[each.value.cluster_key].zone
  cluster_name = module.gke_clusters[each.value.cluster_key].name

  machine_type   = each.value.machine_type
  spot           = each.value.spot
  min_node_count = each.value.min_node_count
  max_node_count = each.value.max_node_count
  disk_size_gb   = each.value.disk_size_gb
  disk_type      = each.value.disk_type
  auto_repair    = each.value.auto_repair
  auto_upgrade   = each.value.auto_upgrade
  oauth_scopes   = each.value.oauth_scopes
}
```

### Client Configuration (`tfvars/orel/dev.tfvars`)

```hcl
# --- Identity & Project ---
client_name  = "orel"
product_name = "gob"
environment  = "dev"
project_id   = "orel-bh-sandbox"
region       = "europe-west1"

# --- APIs ---
apis = ["container.googleapis.com"]

# --- GKE Clusters ---
gke_clusters = {
  "main" = {
    subnet_key             = "gke"
    zone                   = "europe-west1-b"
    master_ipv4_cidr_block = "172.16.0.0/28"
    release_channel        = "REGULAR"
    master_authorized_networks = {
      "allow-all" = {
        cidr_block = "0.0.0.0/0"
      }
    }
  }
}

# --- Node Pools ---
node_pools = {
  "spot" = {
    cluster_key    = "main"
    machine_type   = "e2-medium"
    spot           = true
    min_node_count = 1
    max_node_count = 3
    disk_size_gb   = 50
  }
}
```

---

## Cross-Layer Dependencies

```
networking (Stage 1)
  ├── vpc_self_links["main"]              → gke_cluster.network_id
  ├── subnet_self_links["gke"]            → gke_cluster.subnet_id
  └── subnet_secondary_range_names["gke"]
      ├── ["pods"]                        → gke_cluster.pods_secondary_range_name
      └── ["services"]                    → gke_cluster.services_secondary_range_name

database (Stage 2)
  └── (not consumed by compute — will be consumed in Stage 4/5 for Cloud SQL Proxy)
```

---

## How to Run

```bash
# From project root
terraform -chdir=gob/compute init -backend-config="prefix=orel/dev/compute"
terraform -chdir=gob/compute validate
terraform -chdir=gob/compute plan -var-file=tfvars/orel/dev.tfvars
terraform -chdir=gob/compute apply -var-file=tfvars/orel/dev.tfvars

# Destroy (before networking!)
terraform -chdir=gob/compute destroy -var-file=tfvars/orel/dev.tfvars
```

---

## GCP Console Verification Checklist (after apply)

1. **Kubernetes Engine > Clusters** — `orel-gob-dev-euw1-gke-main` exists
   - Type: Zonal (europe-west1-b)
   - Mode: Standard
   - Release channel: Regular
2. **Cluster > Networking** — VPC-native enabled
   - Pod address range: 10.4.0.0/14
   - Service address range: 10.8.0.0/20
   - Private cluster: nodes private, endpoint public
   - Master authorized networks: configured
3. **Cluster > Security** — Workload Identity enabled
   - Pool: `orel-bh-sandbox.svc.id.goog`
4. **Cluster > Nodes** — 1 node pool `orel-gob-dev-euw1-gke-main-spot`
   - Machine type: e2-medium
   - Provisioning model: Spot
   - Autoscaling: 1-3 nodes
   - Auto-repair: enabled
   - Auto-upgrade: enabled
5. **APIs** — container.googleapis.com enabled

---

## Cost Estimate (Ephemeral — ~8 hrs/day)

| Resource | Monthly (24/7) | Monthly (Ephemeral ~8h/day) |
|----------|---------------|---------------------------|
| GKE Management (Zonal) | $0 | $0 |
| Spot e2-medium × 1-3 nodes | $10-30 | $3-10 |
| Boot disk (50GB pd-standard) | $2 | $2 |
| **Total Stage 3** | **$12-32** | **$5-12** |

Combined with Stage 1+2 (~$15-20 ephemeral), total is well within $70/mo budget.
