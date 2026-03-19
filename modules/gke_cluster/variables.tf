variable "name" {
  description = "Full name for the GKE cluster (pre-computed by caller)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "GKE location — a zone for zonal clusters (e.g. europe-west1-b) or a region for regional clusters"
  type        = string
}

variable "network_id" {
  description = "VPC network self_link"
  type        = string
}

variable "subnet_id" {
  description = "Subnet self_link for the GKE nodes"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Name of the subnet secondary range for Pod IPs (VPC-native)"
  type        = string
}

variable "services_secondary_range_name" {
  description = "Name of the subnet secondary range for Service IPs (VPC-native)"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the control plane's private endpoint (must be /28, must not overlap with any subnet)"
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0)) && endswith(var.master_ipv4_cidr_block, "/28")
    error_message = "Master CIDR must be a valid /28 CIDR block."
  }
}

variable "master_authorized_networks" {
  description = "Map of CIDR blocks authorized to access the Kubernetes API. Key = descriptive name, value = { cidr_block }."
  type = map(object({
    cidr_block = string
  }))
  default = {}
}

variable "release_channel" {
  description = "GKE release channel: UNSPECIFIED, RAPID, REGULAR, STABLE"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["UNSPECIFIED", "RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be UNSPECIFIED, RAPID, REGULAR, or STABLE."
  }
}

variable "workload_identity_enabled" {
  description = "Enable Workload Identity (recommended for secure Pod-to-GCP-service authentication)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion. Set to false for ephemeral environments."
  type        = bool
  default     = false
}

variable "gateway_api_enabled" {
  description = "Enable GKE Gateway API (installs gateway.networking.k8s.io CRDs)"
  type        = bool
  default     = true
}

variable "enable_shielded_nodes" {
  description = "Enable Shielded GKE Nodes (secure boot, integrity monitoring)"
  type        = bool
  default     = true
}

variable "logging_service" {
  description = "Logging service: logging.googleapis.com/kubernetes or none"
  type        = string
  default     = "logging.googleapis.com/kubernetes"

  validation {
    condition     = contains(["logging.googleapis.com/kubernetes", "none"], var.logging_service)
    error_message = "Logging service must be logging.googleapis.com/kubernetes or none."
  }
}

variable "monitoring_service" {
  description = "Monitoring service: monitoring.googleapis.com/kubernetes or none"
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"

  validation {
    condition     = contains(["monitoring.googleapis.com/kubernetes", "none"], var.monitoring_service)
    error_message = "Monitoring service must be monitoring.googleapis.com/kubernetes or none."
  }
}

variable "maintenance_window_start_time" {
  description = "Daily maintenance window start time in UTC (HH:MM format)"
  type        = string
  default     = "02:00"

  validation {
    condition     = can(regex("^([01]\\d|2[0-3]):[0-5]\\d$", var.maintenance_window_start_time))
    error_message = "Maintenance window start time must be in HH:MM format."
  }
}

variable "datapath_provider" {
  description = "Datapath provider: LEGACY_DATAPATH (kube-proxy) or ADVANCED_DATAPATH (Dataplane V2 / Cilium). Dataplane V2 provides built-in Network Policy enforcement, eBPF-based networking, and better observability."
  type        = string
  default     = "ADVANCED_DATAPATH"

  validation {
    condition     = contains(["LEGACY_DATAPATH", "ADVANCED_DATAPATH"], var.datapath_provider)
    error_message = "Datapath provider must be LEGACY_DATAPATH or ADVANCED_DATAPATH."
  }
}

variable "security_posture_mode" {
  description = "Security posture mode: DISABLED or BASIC (free). BASIC scans for vulnerabilities and misconfigurations."
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["DISABLED", "BASIC"], var.security_posture_mode)
    error_message = "Security posture mode must be DISABLED or BASIC."
  }
}

variable "security_posture_vulnerability_mode" {
  description = "Vulnerability scanning mode: DISABLED or VULNERABILITY_BASIC (free). Scans container images for known CVEs."
  type        = string
  default     = "VULNERABILITY_BASIC"

  validation {
    condition     = contains(["DISABLED", "VULNERABILITY_BASIC"], var.security_posture_vulnerability_mode)
    error_message = "Vulnerability mode must be DISABLED or VULNERABILITY_BASIC."
  }
}

variable "labels" {
  description = "GCP labels to apply to the GKE cluster"
  type        = map(string)
  default     = {}
}
