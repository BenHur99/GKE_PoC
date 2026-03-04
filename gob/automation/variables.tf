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
# WIF Pools
# =============================================================================

variable "wif_pools" {
  description = "Map of Workload Identity Federation pool configurations. Key = pool name suffix."
  type = map(object({
    display_name        = optional(string, "")
    provider_id         = string
    issuer_uri          = string
    attribute_mapping   = map(string)
    attribute_condition = optional(string, "")
  }))
  default = {}
}

# =============================================================================
# Service Accounts
# =============================================================================

variable "service_accounts" {
  description = "Map of service account configurations for CI/CD. Key = SA name suffix."
  type = map(object({
    display_name = optional(string, "")
    description  = optional(string, "")
    roles        = optional(list(string), [])
    wif_pool_key = string
    github_repo  = string
  }))
  default = {}
}
