# =============================================================================
# Common Variables (same across all layers)
# =============================================================================

variable "client_name" {
  description = "Client/organization name for resource naming"
  type        = string
}

variable "product_name" {
  description = "Product name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

# =============================================================================
# APIs
# =============================================================================

variable "apis" {
  description = "List of GCP APIs to enable"
  type        = list(string)
  default     = []
}

# =============================================================================
# GKE Clusters
# =============================================================================

variable "gke_clusters" {
  description = "Map of GKE cluster configurations. Key = cluster name suffix."
  type = map(object({
    vpc_key                       = optional(string, "main")
    subnet_key                    = string
    pods_secondary_range_key      = optional(string, "pods")
    services_secondary_range_key  = optional(string, "services")
    zone                          = string
    master_ipv4_cidr_block        = optional(string, "172.16.0.0/28")
    release_channel               = optional(string, "REGULAR")
    workload_identity_enabled     = optional(bool, true)
    deletion_protection           = optional(bool, false)
    gateway_api_enabled           = optional(bool, true)
    master_authorized_networks    = optional(map(object({
      cidr_block = string
    })), {})
    enable_shielded_nodes           = optional(bool, true)
    logging_service                 = optional(string, "logging.googleapis.com/kubernetes")
    monitoring_service              = optional(string, "monitoring.googleapis.com/kubernetes")
    maintenance_window_start_time   = optional(string, "02:00")
    datapath_provider                       = optional(string, "ADVANCED_DATAPATH")
    security_posture_mode                   = optional(string, "BASIC")
    security_posture_vulnerability_mode     = optional(string, "VULNERABILITY_BASIC")
  }))
  default = {}
}

# =============================================================================
# Node Pools
# =============================================================================

variable "node_pools" {
  description = "Map of GKE node pool configurations. Key = pool name suffix."
  type = map(object({
    cluster_key    = string
    machine_type   = optional(string, "e2-medium")
    spot           = optional(bool, true)
    min_node_count = optional(number, 1)
    max_node_count = optional(number, 3)
    disk_size_gb   = optional(number, 50)
    disk_type      = optional(string, "pd-standard")
    auto_repair    = optional(bool, true)
    auto_upgrade   = optional(bool, true)
    oauth_scopes   = optional(list(string), ["https://www.googleapis.com/auth/cloud-platform"])
    image_type     = optional(string, "COS_CONTAINERD")
  }))
  default = {}
}
