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

  validation {
    condition     = contains(["PD_SSD", "PD_HDD"], var.disk_type)
    error_message = "Disk type must be PD_SSD or PD_HDD."
  }
}

variable "availability_type" {
  description = "ZONAL (single zone) or REGIONAL (HA with automatic failover)"
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "Availability type must be ZONAL or REGIONAL."
  }
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

  validation {
    condition     = can(regex("^([01]\\d|2[0-3]):[0-5]\\d$", var.backup_start_time))
    error_message = "Backup start time must be in HH:MM format (00:00-23:59)."
  }
}

variable "query_insights_enabled" {
  description = "Enable Query Insights (free on PostgreSQL — shows slow queries, execution plans, lock analysis)"
  type        = bool
  default     = true
}

variable "maintenance_window_day" {
  description = "Day of week for maintenance window (1=Mon, 7=Sun). Prevents patching during business hours."
  type        = number
  default     = 7

  validation {
    condition     = var.maintenance_window_day >= 1 && var.maintenance_window_day <= 7
    error_message = "Maintenance window day must be 1 (Monday) through 7 (Sunday)."
  }
}

variable "maintenance_window_hour" {
  description = "Hour of day (UTC) for maintenance window start (0-23)"
  type        = number
  default     = 2

  validation {
    condition     = var.maintenance_window_hour >= 0 && var.maintenance_window_hour <= 23
    error_message = "Maintenance window hour must be 0-23."
  }
}

variable "maintenance_window_update_track" {
  description = "Maintenance update track: canary (early) or stable (delayed)"
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["canary", "stable"], var.maintenance_window_update_track)
    error_message = "Update track must be canary or stable."
  }
}

variable "labels" {
  description = "GCP labels to apply to the Cloud SQL instance"
  type        = map(string)
  default     = {}
}
