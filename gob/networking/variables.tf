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

variable "apis" {
  description = "List of GCP APIs to enable"
  type        = list(string)
  default     = []
}

variable "vpcs" {
  description = "Map of VPC configurations. Key = VPC name suffix."
  type        = map(object({}))
  default     = {}
}

variable "subnets" {
  description = "Map of subnet configurations. Key = subnet name suffix."
  type = map(object({
    vpc_key               = string
    cidr                  = string
    purpose               = optional(string, "PRIVATE")
    role                  = optional(string, null)
    private_google_access = optional(bool, true)
    secondary_ranges = optional(map(object({
      cidr = string
    })), {})
  }))
  default = {}
}

variable "firewall_rules" {
  description = "Map of firewall rule configurations. Key = rule name suffix."
  type = map(object({
    vpc_key            = string
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

variable "cloud_nats" {
  description = "Map of Cloud NAT configurations. Key = NAT name suffix."
  type = map(object({
    vpc_key                            = string
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    min_ports_per_vm                   = optional(number, 64)
    max_ports_per_vm                   = optional(number, 4096)
    log_filter                         = optional(string, "ERRORS_ONLY")
  }))
  default = {}
}

variable "psa_connections" {
  description = "Map of PSA configurations. Key = PSA name suffix."
  type = map(object({
    vpc_key = string
    cidr    = string
  }))
  default = {}
}
