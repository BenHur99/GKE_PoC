# modules/networking/variables.tf

# --- Project & Region ---

variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "The GCP region for all regional resources"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

# --- APIs ---

variable "apis" {
  description = "List of GCP APIs to enable in the project"
  type        = list(string)
  default     = []
}

# --- Subnets ---

variable "subnets" {
  description = <<-EOT
    Map of subnets to create in the VPC.
    Key = subnet name suffix (will be prefixed with vpc_name).

    Fields:
    - cidr: The primary IP CIDR range for the subnet
    - purpose: PRIVATE (default) or REGIONAL_MANAGED_PROXY (for ALB)
    - role: Set to ACTIVE for proxy-only subnets, null otherwise
    - private_google_access: Enable Private Google Access (default: true)
    - secondary_ranges: Map of secondary ranges (for GKE pods/services)
  EOT

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

# --- Firewall ---

variable "firewall_rules" {
  description = <<-EOT
    Map of firewall rules to create in the VPC.
    Key = rule name suffix (will be prefixed with vpc_name).

    Fields:
    - direction: INGRESS (default) or EGRESS
    - priority: Rule priority (lower = higher priority). Default: 1000
    - action: "allow" or "deny"
    - protocol: Protocol (tcp, udp, icmp, all)
    - ports: List of port ranges (e.g., ["80", "443", "8080-8090"])
    - source_ranges: Source CIDR ranges (for INGRESS)
    - destination_ranges: Destination CIDR ranges (for EGRESS)
    - target_tags: Network tags to apply rule to
    - source_tags: Source network tags (for INGRESS)
  EOT

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

# --- NAT ---

variable "nat_config" {
  description = <<-EOT
    Configuration for Cloud NAT.
    Set to null to skip NAT creation.

    Fields:
    - nat_ip_allocate_option: AUTO_ONLY (default) or MANUAL_ONLY
    - source_subnetwork_ip_ranges_to_nat: Which subnet ranges to NAT
    - min_ports_per_vm: Minimum ports per VM (default: 64)
    - max_ports_per_vm: Maximum ports per VM (default: 4096)
    - log_filter: Logging filter (default: ERRORS_ONLY)
  EOT

  type = object({
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    min_ports_per_vm                   = optional(number, 64)
    max_ports_per_vm                   = optional(number, 4096)
    log_filter                         = optional(string, "ERRORS_ONLY")
  })
  default = null
}

# --- PSA ---

variable "psa_ranges" {
  description = <<-EOT
    Map of Private Services Access IP ranges to allocate.
    Key = allocation name. These ranges are used by Google-managed
    services (Cloud SQL, Memorystore, etc.) via VPC peering.

    Fields:
    - cidr: The CIDR range to allocate for Google services
  EOT

  type = map(object({
    cidr = string
  }))
  default = {}
}
