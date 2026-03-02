variable "name" {
  description = "Service account ID (max 30 chars, used as account_id)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "display_name" {
  description = "Display name for the service account"
  type        = string
  default     = ""
}

variable "description" {
  description = "Description of the service account"
  type        = string
  default     = ""
}

variable "roles" {
  description = "List of IAM roles to grant to this service account at the project level"
  type        = list(string)
  default     = []
}
