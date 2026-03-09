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
# Workload Identity Bindings
# =============================================================================

variable "wi_bindings" {
  description = "Map of Workload Identity bindings. Key = binding name suffix."
  type = map(object({
    gsa_key       = string
    k8s_namespace = optional(string, "default")
    ksa_name      = string
  }))
  default = {}
}
