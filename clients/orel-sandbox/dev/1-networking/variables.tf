# clients/orel-sandbox/dev/1-networking/variables.tf

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "apis" {
  description = "List of GCP APIs to enable"
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    cidr                  = string
    purpose               = optional(string, "PRIVATE")
    role                  = optional(string, null)
    private_google_access = optional(bool, true)
    secondary_ranges = optional(map(object({
      cidr = string
    })), {})
  }))
}

variable "firewall_rules" {
  description = "Map of firewall rule configurations"
  type = map(object({
    direction          = optional(string, "INGRESS")
    priority           = optional(number, 1000)
    action             = string
    protocol           = string
    ports              = optional(list(string), [])
    source_ranges      = optional(list(string), [])
    destination_ranges = optional(list(string), [])
    target_tags        = optional(list(string), [])
    source_tags        = optional(list(string), [])
  }))
  default = {}
}

variable "nat_config" {
  description = "Cloud NAT configuration. Set to null to skip NAT creation."
  type = object({
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    min_ports_per_vm                   = optional(number, 64)
    max_ports_per_vm                   = optional(number, 4096)
    log_filter                         = optional(string, "ERRORS_ONLY")
  })
  default = null
}

variable "psa_ranges" {
  description = "Map of Private Services Access IP range allocations"
  type = map(object({
    cidr = string
  }))
  default = {}
}
