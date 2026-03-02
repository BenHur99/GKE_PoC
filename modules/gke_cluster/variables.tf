variable "name" {
  description = "Full name for the GKE cluster (pre-computed by caller)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "GKE location — a zone for zonal clusters (e.g. europe-west1-b) or a region for regional clusters"
  type        = string
}

variable "network_id" {
  description = "VPC network self_link"
  type        = string
}

variable "subnet_id" {
  description = "Subnet self_link for the GKE nodes"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Name of the subnet secondary range for Pod IPs (VPC-native)"
  type        = string
}

variable "services_secondary_range_name" {
  description = "Name of the subnet secondary range for Service IPs (VPC-native)"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the control plane's private endpoint (must be /28, must not overlap with any subnet)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "Map of CIDR blocks authorized to access the Kubernetes API. Key = descriptive name, value = { cidr_block }."
  type = map(object({
    cidr_block = string
  }))
  default = {}
}

variable "release_channel" {
  description = "GKE release channel: UNSPECIFIED, RAPID, REGULAR, STABLE"
  type        = string
  default     = "REGULAR"
}

variable "workload_identity_enabled" {
  description = "Enable Workload Identity (recommended for secure Pod-to-GCP-service authentication)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion. Set to false for ephemeral environments."
  type        = bool
  default     = false
}
