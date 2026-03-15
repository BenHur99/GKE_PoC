variable "name" {
  description = "Full name for the static IP address (pre-computed by caller)"
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

variable "address_type" {
  description = "Address type: EXTERNAL or INTERNAL"
  type        = string
  default     = "EXTERNAL"

  validation {
    condition     = contains(["EXTERNAL", "INTERNAL"], var.address_type)
    error_message = "Address type must be EXTERNAL or INTERNAL."
  }
}

variable "network_tier" {
  description = "Network tier: PREMIUM or STANDARD"
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["PREMIUM", "STANDARD"], var.network_tier)
    error_message = "Network tier must be PREMIUM or STANDARD."
  }
}

variable "labels" {
  description = "GCP labels to apply to the static IP"
  type        = map(string)
  default     = {}
}
