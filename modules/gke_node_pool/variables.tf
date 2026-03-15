variable "name" {
  description = "Full name for the node pool (pre-computed by caller)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "GKE location — must match the cluster's location"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster this pool belongs to"
  type        = string
}

variable "machine_type" {
  description = "GCE machine type for the nodes"
  type        = string
  default     = "e2-medium"
}

variable "spot" {
  description = "Use Spot VMs (preemptible replacement, up to 90% cheaper)"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 3
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "disk_type" {
  description = "Boot disk type: pd-standard, pd-ssd, pd-balanced"
  type        = string
  default     = "pd-standard"
}

variable "auto_repair" {
  description = "Enable auto-repair for failed/unhealthy nodes"
  type        = bool
  default     = true
}

variable "auto_upgrade" {
  description = "Enable automatic node version upgrades"
  type        = bool
  default     = true
}

variable "oauth_scopes" {
  description = "OAuth scopes for node service account"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "labels" {
  description = "GCP labels to apply to the node pool"
  type        = map(string)
  default     = {}
}
