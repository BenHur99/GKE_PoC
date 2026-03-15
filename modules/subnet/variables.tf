variable "name" {
  description = "Full name of the subnet"
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

variable "network_id" {
  description = "VPC network ID to attach subnet to"
  type        = string
}

variable "cidr" {
  description = "Primary IP CIDR range"
  type        = string
}

variable "purpose" {
  description = "Subnet purpose: PRIVATE or REGIONAL_MANAGED_PROXY"
  type        = string
  default     = "PRIVATE"

  validation {
    condition     = contains(["PRIVATE", "REGIONAL_MANAGED_PROXY"], var.purpose)
    error_message = "Purpose must be PRIVATE or REGIONAL_MANAGED_PROXY."
  }
}

variable "role" {
  description = "Subnet role: ACTIVE for proxy-only subnets, null otherwise"
  type        = string
  default     = null
}

variable "private_google_access" {
  description = "Enable Private Google Access"
  type        = bool
  default     = true
}

variable "secondary_ranges" {
  description = "Map of secondary IP ranges (for GKE pods/services)"
  type = map(object({
    cidr = string
  }))
  default = {}
}
