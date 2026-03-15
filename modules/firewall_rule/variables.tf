variable "name" {
  description = "Full name of the firewall rule"
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

variable "direction" {
  description = "Direction: INGRESS or EGRESS"
  type        = string
  default     = "INGRESS"

  validation {
    condition     = contains(["INGRESS", "EGRESS"], var.direction)
    error_message = "Direction must be INGRESS or EGRESS."
  }
}

variable "priority" {
  description = "Rule priority (lower = higher priority)"
  type        = number
  default     = 1000

  validation {
    condition     = var.priority >= 0 && var.priority <= 65535
    error_message = "Priority must be between 0 and 65535."
  }
}

variable "action" {
  description = "Action: allow or deny"
  type        = string

  validation {
    condition     = contains(["allow", "deny"], var.action)
    error_message = "Action must be allow or deny."
  }
}

variable "protocol" {
  description = "Protocol: tcp, udp, icmp, all"
  type        = string

  validation {
    condition     = contains(["tcp", "udp", "icmp", "all"], var.protocol)
    error_message = "Protocol must be tcp, udp, icmp, or all."
  }
}

variable "ports" {
  description = "List of ports or port ranges"
  type        = list(string)
  default     = []
}

variable "source_ranges" {
  description = "Source CIDR ranges (for INGRESS)"
  type        = list(string)
  default     = []
}

variable "destination_ranges" {
  description = "Destination CIDR ranges (for EGRESS)"
  type        = list(string)
  default     = []
}

variable "target_tags" {
  description = "Network tags to apply rule to"
  type        = list(string)
  default     = []
}

variable "source_tags" {
  description = "Source network tags (for INGRESS)"
  type        = list(string)
  default     = []
}
