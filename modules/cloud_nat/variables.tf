variable "name" {
  description = "Base name for router and NAT (suffixed with -router and -nat)"
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
  description = "VPC network ID"
  type        = string
}

variable "nat_ip_allocate_option" {
  description = "How external IPs are allocated: AUTO_ONLY or MANUAL_ONLY"
  type        = string
  default     = "AUTO_ONLY"

  validation {
    condition     = contains(["AUTO_ONLY", "MANUAL_ONLY"], var.nat_ip_allocate_option)
    error_message = "NAT IP allocate option must be AUTO_ONLY or MANUAL_ONLY."
  }
}

variable "source_subnetwork_ip_ranges_to_nat" {
  description = "Which subnet ranges to NAT: ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, or LIST_OF_SUBNETWORKS"
  type        = string
  default     = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  validation {
    condition     = contains(["ALL_SUBNETWORKS_ALL_IP_RANGES", "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES", "LIST_OF_SUBNETWORKS"], var.source_subnetwork_ip_ranges_to_nat)
    error_message = "Must be ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, or LIST_OF_SUBNETWORKS."
  }
}

variable "subnetworks" {
  description = "List of subnet self_links to NAT (used when source_subnetwork_ip_ranges_to_nat = LIST_OF_SUBNETWORKS)"
  type = list(object({
    name                    = string
    source_ip_ranges_to_nat = optional(list(string), ["ALL_IP_RANGES"])
  }))
  default = []
}

variable "min_ports_per_vm" {
  description = "Minimum number of ports per VM"
  type        = number
  default     = 64
}

variable "max_ports_per_vm" {
  description = "Maximum number of ports per VM"
  type        = number
  default     = 4096
}

variable "log_filter" {
  description = "NAT log filter: ERRORS_ONLY, TRANSLATIONS_ONLY, ALL"
  type        = string
  default     = "ERRORS_ONLY"

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.log_filter)
    error_message = "Log filter must be ERRORS_ONLY, TRANSLATIONS_ONLY, or ALL."
  }
}
