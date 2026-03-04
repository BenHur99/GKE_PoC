variable "name" {
  description = "Workload Identity Pool ID"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "display_name" {
  description = "Display name for the WIF pool"
  type        = string
  default     = ""
}

variable "provider_id" {
  description = "Workload Identity Pool Provider ID"
  type        = string
}

variable "issuer_uri" {
  description = "OIDC Issuer URI (e.g. https://token.actions.githubusercontent.com)"
  type        = string
}

variable "attribute_mapping" {
  description = "Map of attribute mappings from OIDC claims to Google attributes"
  type        = map(string)
}

variable "attribute_condition" {
  description = "CEL expression that must evaluate to true for token exchange to succeed"
  type        = string
  default     = ""
}
