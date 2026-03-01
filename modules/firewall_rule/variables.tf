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
}

variable "priority" {
  description = "Rule priority (lower = higher priority)"
  type        = number
  default     = 1000
}

variable "action" {
  description = "Action: allow or deny"
  type        = string
}

variable "protocol" {
  description = "Protocol: tcp, udp, icmp, all"
  type        = string
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
