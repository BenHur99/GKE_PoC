variable "name" {
  description = "Full name for the Cloud SQL instance (pre-computed by caller)"
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

variable "database_version" {
  description = "Database engine version (e.g. POSTGRES_15)"
  type        = string
}

variable "tier" {
  description = "Machine tier (e.g. db-f1-micro, db-custom-1-3840)"
  type        = string
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 10
}

variable "disk_type" {
  description = "Disk type: PD_SSD or PD_HDD"
  type        = string
  default     = "PD_SSD"
}

variable "availability_type" {
  description = "ZONAL (single zone) or REGIONAL (HA with automatic failover)"
  type        = string
  default     = "ZONAL"
}

variable "network_id" {
  description = "VPC network self_link for private IP connectivity"
  type        = string
}

variable "database_name" {
  description = "Name of the database to create inside the instance"
  type        = string
}

variable "database_flags" {
  description = "Map of database flags (key = flag name, value = flag value)"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Prevent accidental deletion of the instance"
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = false
}

variable "backup_start_time" {
  description = "HH:MM time for daily backup window (UTC)"
  type        = string
  default     = "03:00"
}
