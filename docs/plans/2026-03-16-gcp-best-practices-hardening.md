# GCP Best Practices Hardening — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align GCP infrastructure with Google-recommended best practices (free changes only — zero cost impact).

**Architecture:** 5 focused changes across 3 layers (networking, database, compute) and 3 modules (firewall_rule, cloud_sql, gke_cluster). Each change fixes a specific GCP best-practice gap.

**Tech Stack:** Terraform >= 1.6, Google Provider >= 6.0, GCS Backend

---

## Summary of Changes

| # | Fix | Layer/Module | Cost |
|---|-----|-------------|------|
| 1 | Firewall rules: add `labels` support | `modules/firewall_rule` + `gob/networking` | Free |
| 2 | Cloud NAT: restrict to specific subnets | `modules/cloud_nat` + `gob/networking` | Free |
| 3 | Cloud SQL: add query insights + maintenance window | `modules/cloud_sql` + `gob/database` | Free |
| 4 | GKE Cluster: add Dataplane V2 + security posture + image type | `modules/gke_cluster` + `modules/gke_node_pool` + `gob/compute` | Free |
| 5 | GKE Node Pool: add dedicated node service account | `modules/gke_node_pool` + `gob/compute` | Free |

---

### Task 1: Firewall Rules — Add Labels Support

**Why:** Every GCP resource that supports labels should have them. Labels enable filtering in Console, billing reports, and audit logs. `google_compute_firewall` supports labels but the module doesn't expose them.

**Files:**
- Modify: `modules/firewall_rule/variables.tf` — add `labels` variable
- Modify: `modules/firewall_rule/main.tf` — pass `labels` to resource
- Modify: `gob/networking/main.tf:63-79` — pass `labels` to firewall module

**Step 1: Add labels variable to firewall_rule module**

In `modules/firewall_rule/variables.tf`, add at the end:

```hcl
variable "labels" {
  description = "GCP labels to apply to the firewall rule"
  type        = map(string)
  default     = {}
}
```

**Step 2: Pass labels to the resource**

In `modules/firewall_rule/main.tf`, add inside `google_compute_firewall "this"` (after line 6, after `priority`):

```hcl
  # Add this line after priority:
  labels = var.labels
```

The resource block should look like:
```hcl
resource "google_compute_firewall" "this" {
  name      = var.name
  project   = var.project_id
  network   = var.network_id
  direction = var.direction
  priority  = var.priority
  labels    = var.labels
  ...
```

**Step 3: Pass labels from networking layer**

In `gob/networking/main.tf`, in the `module "firewall_rules"` block (line 63-79), add after `source_tags`:

```hcl
  labels             = module.naming.common_labels
```

**Step 4: Validate**

Run: `terraform -chdir=gob/networking validate`
Expected: `Success! The configuration is valid.`

**Step 5: Commit**

```bash
git add modules/firewall_rule/variables.tf modules/firewall_rule/main.tf gob/networking/main.tf
git commit -m "feat(networking): add labels to firewall rules for GCP governance"
```

---

### Task 2: Cloud NAT — Restrict to Specific Subnets

**Why:** `ALL_SUBNETWORKS_ALL_IP_RANGES` gives NAT to every subnet including the proxy subnet. Google recommends `LIST_OF_SUBNETWORKS` with explicit subnet selection for production — you control exactly which subnets get internet egress.

**Files:**
- Modify: `modules/cloud_nat/variables.tf` — add `subnetworks` variable
- Modify: `modules/cloud_nat/main.tf` — add dynamic `subnetwork` block
- Modify: `gob/networking/variables.tf:70-81` — add `subnetworks` to cloud_nats type
- Modify: `gob/networking/main.tf:85-98` — pass subnetworks to module
- Modify: `gob/networking/tfvars/orel/dev.tfvars:92-96` — configure specific subnets

**Step 1: Add subnetworks variable to cloud_nat module**

In `modules/cloud_nat/variables.tf`, add after `source_subnetwork_ip_ranges_to_nat` (after line 36):

```hcl
variable "subnetworks" {
  description = "List of subnet self_links to NAT (used when source_subnetwork_ip_ranges_to_nat = LIST_OF_SUBNETWORKS)"
  type = list(object({
    name                    = string
    source_ip_ranges_to_nat = optional(list(string), ["ALL_IP_RANGES"])
  }))
  default = []
}
```

**Step 2: Add dynamic subnetwork block to cloud_nat resource**

In `modules/cloud_nat/main.tf`, add inside `google_compute_router_nat "this"` (after line 16, after `max_ports_per_vm`):

```hcl
  dynamic "subnetwork" {
    for_each = var.subnetworks
    content {
      name                    = subnetwork.value.name
      source_ip_ranges_to_nat = subnetwork.value.source_ip_ranges_to_nat
    }
  }
```

**Step 3: Update networking layer variable type**

In `gob/networking/variables.tf`, replace the `cloud_nats` variable (lines 70-81) with:

```hcl
variable "cloud_nats" {
  description = "Map of Cloud NAT configurations. Key = NAT name suffix."
  type = map(object({
    vpc_key                            = string
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    subnet_keys                        = optional(list(string), [])
    min_ports_per_vm                   = optional(number, 64)
    max_ports_per_vm                   = optional(number, 4096)
    log_filter                         = optional(string, "ERRORS_ONLY")
  }))
  default = {}
}
```

**Step 4: Pass subnetworks from networking layer**

In `gob/networking/main.tf`, replace the `module "cloud_nats"` block (lines 85-98) with:

```hcl
module "cloud_nats" {
  for_each = var.cloud_nats
  source   = "../../modules/cloud_nat"

  name                               = "${local.naming_prefix}-${each.key}"
  project_id                         = var.project_id
  region                             = var.region
  network_id                         = module.vpcs[each.value.vpc_key].id
  nat_ip_allocate_option             = each.value.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = each.value.source_subnetwork_ip_ranges_to_nat
  subnetworks = [
    for sk in each.value.subnet_keys : {
      name = module.subnets[sk].self_link
    }
  ]
  min_ports_per_vm                   = each.value.min_ports_per_vm
  max_ports_per_vm                   = each.value.max_ports_per_vm
  log_filter                         = each.value.log_filter
}
```

**Step 5: Update dev.tfvars**

In `gob/networking/tfvars/orel/dev.tfvars`, replace the `cloud_nats` block (lines 92-96) with:

```hcl
cloud_nats = {
  "main" = {
    vpc_key                            = "main"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    subnet_keys                        = ["gke"]
  }
}
```

**Step 6: Validate**

Run: `terraform -chdir=gob/networking validate`
Expected: `Success! The configuration is valid.`

**Step 7: Commit**

```bash
git add modules/cloud_nat/variables.tf modules/cloud_nat/main.tf gob/networking/variables.tf gob/networking/main.tf gob/networking/tfvars/orel/dev.tfvars
git commit -m "feat(networking): restrict Cloud NAT to specific subnets per GCP best practice"
```

---

### Task 3: Cloud SQL — Add Query Insights + Maintenance Window

**Why:** Query Insights is free on PostgreSQL and provides slow-query analysis, execution plans, and lock monitoring. Maintenance window prevents Google from patching your DB during business hours.

**Files:**
- Modify: `modules/cloud_sql/variables.tf` — add query insights + maintenance window variables
- Modify: `modules/cloud_sql/main.tf` — add `insights_config` + `maintenance_window` blocks
- Modify: `gob/database/tfvars/orel/dev.tfvars` — set maintenance window

**Step 1: Add variables to cloud_sql module**

In `modules/cloud_sql/variables.tf`, add after `backup_start_time` validation block (after line 91, before `labels`):

```hcl
variable "query_insights_enabled" {
  description = "Enable Query Insights (free on PostgreSQL — shows slow queries, execution plans, lock analysis)"
  type        = bool
  default     = true
}

variable "maintenance_window_day" {
  description = "Day of week for maintenance window (1=Mon, 7=Sun). Prevents patching during business hours."
  type        = number
  default     = 7

  validation {
    condition     = var.maintenance_window_day >= 1 && var.maintenance_window_day <= 7
    error_message = "Maintenance window day must be 1 (Monday) through 7 (Sunday)."
  }
}

variable "maintenance_window_hour" {
  description = "Hour of day (UTC) for maintenance window start (0-23)"
  type        = number
  default     = 2

  validation {
    condition     = var.maintenance_window_hour >= 0 && var.maintenance_window_hour <= 23
    error_message = "Maintenance window hour must be 0-23."
  }
}

variable "maintenance_window_update_track" {
  description = "Maintenance update track: canary (early) or stable (delayed)"
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["canary", "stable"], var.maintenance_window_update_track)
    error_message = "Update track must be canary or stable."
  }
}
```

**Step 2: Add insights_config and maintenance_window to Cloud SQL resource**

In `modules/cloud_sql/main.tf`, add inside the `settings` block — after the `backup_configuration` block (after line 31, before the closing `}` of `settings`):

```hcl
    insights_config {
      query_insights_enabled  = var.query_insights_enabled
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_window_update_track
    }
```

**Step 3: Update database dev.tfvars**

In `gob/database/tfvars/orel/dev.tfvars`, add inside the `sql_instances.main` object (after `database_flags` block, before the closing `}`):

```hcl
    # Maintenance: Sunday 2:00 AM UTC — prevents patching during work hours
    maintenance_window_day  = 7
    maintenance_window_hour = 2
```

**Step 4: Update database layer variable type to pass new fields**

In `gob/database/variables.tf`, add the new optional fields to the `sql_instances` object type (inside the `map(object({...}))`, after `vpc_key`):

```hcl
    query_insights_enabled          = optional(bool, true)
    maintenance_window_day          = optional(number, 7)
    maintenance_window_hour         = optional(number, 2)
    maintenance_window_update_track = optional(string, "stable")
```

**Step 5: Pass new variables from database layer main.tf**

In `gob/database/main.tf`, add to the `module "sql_instances"` block (after `labels`):

```hcl
  query_insights_enabled          = each.value.query_insights_enabled
  maintenance_window_day          = each.value.maintenance_window_day
  maintenance_window_hour         = each.value.maintenance_window_hour
  maintenance_window_update_track = each.value.maintenance_window_update_track
```

**Step 6: Validate**

Run: `terraform -chdir=gob/database validate`
Expected: `Success! The configuration is valid.`

**Step 7: Commit**

```bash
git add modules/cloud_sql/variables.tf modules/cloud_sql/main.tf gob/database/variables.tf gob/database/main.tf gob/database/tfvars/orel/dev.tfvars
git commit -m "feat(database): add Cloud SQL query insights and maintenance window"
```

---

### Task 4: GKE Cluster — Dataplane V2 + Security Posture + Image Type

**Why:**
- **Dataplane V2** (eBPF/Cilium): replaces kube-proxy + Calico with a unified data plane. Gives built-in Network Policy enforcement, better performance, and native visibility. Free, Google-recommended for new clusters.
- **Security Posture**: free BASIC tier scans cluster for vulnerabilities and misconfigurations.
- **Image Type**: explicitly set COS_CONTAINERD — hardened OS, minimal attack surface.

**Files:**
- Modify: `modules/gke_cluster/variables.tf` — add dataplane_provider + security_posture variables
- Modify: `modules/gke_cluster/main.tf` — add new config blocks
- Modify: `modules/gke_node_pool/variables.tf` — add image_type variable
- Modify: `modules/gke_node_pool/main.tf` — pass image_type
- Modify: `gob/compute/variables.tf` — add new fields to object types
- Modify: `gob/compute/main.tf` — pass new variables to modules

**Step 1: Add variables to gke_cluster module**

In `modules/gke_cluster/variables.tf`, add after `maintenance_window_start_time` validation block (after line 121, before `labels`):

```hcl
variable "datapath_provider" {
  description = "Datapath provider: LEGACY_DATAPATH (kube-proxy) or ADVANCED_DATAPATH (Dataplane V2 / Cilium). Dataplane V2 provides built-in Network Policy enforcement, eBPF-based networking, and better observability."
  type        = string
  default     = "ADVANCED_DATAPATH"

  validation {
    condition     = contains(["LEGACY_DATAPATH", "ADVANCED_DATAPATH"], var.datapath_provider)
    error_message = "Datapath provider must be LEGACY_DATAPATH or ADVANCED_DATAPATH."
  }
}

variable "security_posture_mode" {
  description = "Security posture mode: DISABLED or BASIC (free). BASIC scans for vulnerabilities and misconfigurations."
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["DISABLED", "BASIC"], var.security_posture_mode)
    error_message = "Security posture mode must be DISABLED or BASIC."
  }
}

variable "security_posture_vulnerability_mode" {
  description = "Vulnerability scanning mode: DISABLED or VULNERABILITY_BASIC (free). Scans container images for known CVEs."
  type        = string
  default     = "VULNERABILITY_BASIC"

  validation {
    condition     = contains(["DISABLED", "VULNERABILITY_BASIC"], var.security_posture_vulnerability_mode)
    error_message = "Vulnerability mode must be DISABLED or VULNERABILITY_BASIC."
  }
}
```

**Step 2: Add blocks to gke_cluster resource**

In `modules/gke_cluster/main.tf`, add these blocks inside `google_container_cluster "this"`:

After `enable_shielded_nodes` (line 65), add:

```hcl
  # Dataplane V2 (eBPF/Cilium) — replaces kube-proxy, built-in Network Policy
  datapath_provider = var.datapath_provider

  # Security Posture — free vulnerability and misconfiguration scanning
  security_posture_config {
    mode               = var.security_posture_mode
    vulnerability_mode = var.security_posture_vulnerability_mode
  }
```

**Step 3: Add image_type variable to gke_node_pool module**

In `modules/gke_node_pool/variables.tf`, add after `oauth_scopes` (after line 78, before `labels`):

```hcl
variable "image_type" {
  description = "Node OS image type: COS_CONTAINERD (hardened, recommended) or UBUNTU_CONTAINERD"
  type        = string
  default     = "COS_CONTAINERD"

  validation {
    condition     = contains(["COS_CONTAINERD", "UBUNTU_CONTAINERD"], var.image_type)
    error_message = "Image type must be COS_CONTAINERD or UBUNTU_CONTAINERD."
  }
}
```

**Step 4: Pass image_type in gke_node_pool resource**

In `modules/gke_node_pool/main.tf`, add inside `node_config` block (after line 22, after `oauth_scopes`):

```hcl
    image_type   = var.image_type
```

**Step 5: Update compute layer variable types**

In `gob/compute/variables.tf`, add to the `gke_clusters` object type (inside the `map(object({...}))`, after `maintenance_window_start_time`):

```hcl
    datapath_provider                       = optional(string, "ADVANCED_DATAPATH")
    security_posture_mode                   = optional(string, "BASIC")
    security_posture_vulnerability_mode     = optional(string, "VULNERABILITY_BASIC")
```

Add to the `node_pools` object type (after `oauth_scopes`):

```hcl
    image_type     = optional(string, "COS_CONTAINERD")
```

**Step 6: Pass new variables from compute layer main.tf**

In `gob/compute/main.tf`, add to the `module "gke_clusters"` block (after `maintenance_window_start_time`):

```hcl
  datapath_provider                       = each.value.datapath_provider
  security_posture_mode                   = each.value.security_posture_mode
  security_posture_vulnerability_mode     = each.value.security_posture_vulnerability_mode
```

Add to the `module "node_pools"` block (after `oauth_scopes`):

```hcl
  image_type     = each.value.image_type
```

**Step 7: Validate**

Run: `terraform -chdir=gob/compute validate`
Expected: `Success! The configuration is valid.`

**Step 8: Commit**

```bash
git add modules/gke_cluster/variables.tf modules/gke_cluster/main.tf modules/gke_node_pool/variables.tf modules/gke_node_pool/main.tf gob/compute/variables.tf gob/compute/main.tf
git commit -m "feat(compute): add Dataplane V2, security posture, and explicit COS image type"
```

---

### Task 5: GKE Node Pool — Dedicated Node Service Account

**Why:** Without an explicit SA, nodes use the Compute Engine default SA which has `roles/editor` (full project access). Google explicitly recommends a least-privilege node SA with only the roles nodes actually need: writing logs, metrics, and pulling images.

**Files:**
- Modify: `modules/gke_node_pool/variables.tf` — add `service_account` variable
- Modify: `modules/gke_node_pool/main.tf` — pass `service_account` to node_config
- Modify: `gob/compute/variables.tf` — add `node_service_account_email` to gke cluster type
- Modify: `gob/compute/main.tf` — create SA module + pass to node pool
- Modify: `gob/compute/tfvars/orel/dev.tfvars` — add SA config

**Step 1: Add service_account variable to gke_node_pool module**

In `modules/gke_node_pool/variables.tf`, add after `image_type` variable (added in Task 4):

```hcl
variable "service_account" {
  description = "Service account email for the node pool. If empty, uses Compute Engine default SA (NOT recommended)."
  type        = string
  default     = ""
}
```

**Step 2: Pass service_account in gke_node_pool resource**

In `modules/gke_node_pool/main.tf`, add inside `node_config` block (after `image_type`):

```hcl
    service_account = var.service_account != "" ? var.service_account : null
```

**Step 3: Add node SA resources to compute layer**

In `gob/compute/variables.tf`, add a new variable block after `node_pools`:

```hcl
# =============================================================================
# Node Service Accounts
# =============================================================================

variable "node_service_accounts" {
  description = "Map of GKE node service account configurations. Key = SA name suffix."
  type = map(object({
    display_name = optional(string, "")
    description  = optional(string, "")
  }))
  default = {}
}
```

**Step 4: Add node SA module to compute layer main.tf**

In `gob/compute/main.tf`, add after the `module "apis"` block (after line 24) and before the GKE clusters section:

```hcl
# =============================================================================
# Node Service Accounts (least-privilege SA for GKE nodes)
# =============================================================================

module "node_service_accounts" {
  for_each = var.node_service_accounts
  source   = "../../modules/service_account"

  name         = "${local.naming_prefix}-sa-${each.key}"
  project_id   = var.project_id
  display_name = each.value.display_name
  description  = each.value.description
  # Least-privilege roles for GKE nodes:
  # - logging.logWriter: kubelet and agents write logs to Cloud Logging
  # - monitoring.metricWriter: metrics agent writes to Cloud Monitoring
  # - monitoring.viewer: read monitoring data
  # - stackdriver.resourceMetadata.writer: resource metadata for monitoring
  # - artifactregistry.reader: pull container images from Artifact Registry
  roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ]

  depends_on = [module.apis]
}
```

**Step 5: Update node_pools variable type and pass SA to module**

In `gob/compute/variables.tf`, add to the `node_pools` object type (after `image_type`):

```hcl
    node_sa_key    = optional(string, "")
```

In `gob/compute/main.tf`, add to the `module "node_pools"` block (after `image_type`):

```hcl
  service_account = each.value.node_sa_key != "" ? module.node_service_accounts[each.value.node_sa_key].email : ""
```

**Step 6: Update compute dev.tfvars**

In `gob/compute/tfvars/orel/dev.tfvars`, add after `apis` block and before `gke_clusters`:

```hcl
# =============================================================================
# Node Service Accounts (least-privilege, replaces Compute Engine default SA)
# =============================================================================

node_service_accounts = {
  "gke-nodes" = {
    display_name = "GKE Node SA"
    description  = "Least-privilege SA for GKE nodes — replaces default Compute Engine SA (roles/editor)"
  }
}
```

Update the `node_pools.spot` entry to reference the SA:

```hcl
node_pools = {
  "spot" = {
    cluster_key    = "main"
    machine_type   = "e2-medium"
    spot           = true
    min_node_count = 1
    max_node_count = 3
    disk_size_gb   = 50
    node_sa_key    = "gke-nodes"
  }
}
```

**Step 7: Add SA outputs to compute layer**

In `gob/compute/outputs.tf`, add:

```hcl
# --- Node Service Accounts ---

output "node_service_account_emails" {
  description = "Map of node SA key => service account email"
  value       = { for k, v in module.node_service_accounts : k => v.email }
}
```

**Step 8: Validate**

Run: `terraform -chdir=gob/compute validate`
Expected: `Success! The configuration is valid.`

**Step 9: Commit**

```bash
git add modules/gke_node_pool/variables.tf modules/gke_node_pool/main.tf gob/compute/variables.tf gob/compute/main.tf gob/compute/outputs.tf gob/compute/tfvars/orel/dev.tfvars
git commit -m "feat(compute): add dedicated least-privilege node SA, replace default Compute Engine SA"
```

---

## Post-Implementation

After all 5 tasks are done:

1. Run validate on all layers:
   ```bash
   terraform -chdir=gob/networking validate
   terraform -chdir=gob/database validate
   terraform -chdir=gob/compute validate
   ```

2. Update `docs/STATUS.md` with the new best-practice changes.

3. These changes are safe for existing infrastructure:
   - **Firewall labels**: add-only, no recreate
   - **Cloud NAT subnet restriction**: config change, brief NAT reconnection
   - **Cloud SQL insights + maintenance window**: add-only, no restart
   - **GKE Dataplane V2**: ⚠️ **requires cluster recreation** — plan carefully if cluster exists
   - **GKE node SA**: ⚠️ **requires node pool recreation** — nodes will be drained and recreated
