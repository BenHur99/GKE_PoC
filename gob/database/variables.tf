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
# Cloud SQL Instances
# =============================================================================

variable "sql_instances" {
  description = "Map of Cloud SQL instance configurations. Key = instance name suffix."
  type = map(object({
    database_version    = string
    tier                = string
    disk_size           = optional(number, 10)
    disk_type           = optional(string, "PD_SSD")
    availability_type   = optional(string, "ZONAL")
    database_name       = string
    deletion_protection = optional(bool, true)
    backup_enabled      = optional(bool, false)
    backup_start_time   = optional(string, "03:00")
    database_flags      = optional(map(string), {})
    vpc_key             = optional(string, "main")
  }))
  default = {}
}

# =============================================================================
# Service Accounts
# =============================================================================

variable "service_accounts" {
  description = "Map of service account configurations. Key = SA name suffix."
  type = map(object({
    display_name = optional(string, "")
    description  = optional(string, "")
    roles        = optional(list(string), [])
  }))
  default = {}
}
