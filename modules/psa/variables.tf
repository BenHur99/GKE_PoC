variable "name" {
  description = "Full name of the PSA allocation"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "cidr" {
  description = "CIDR range to allocate for Google services"
  type        = string
}
