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
}

variable "source_subnetwork_ip_ranges_to_nat" {
  description = "Which subnet ranges to NAT"
  type        = string
  default     = "ALL_SUBNETWORKS_ALL_IP_RANGES"
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
}
