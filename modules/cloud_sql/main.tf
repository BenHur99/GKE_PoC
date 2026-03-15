resource "google_sql_database_instance" "this" {
  name                = var.name
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    availability_type = var.availability_type
    user_labels       = var.labels

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }

    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.key
        value = database_flags.value
      }
    }

    backup_configuration {
      enabled    = var.backup_enabled
      start_time = var.backup_enabled ? var.backup_start_time : null
    }
  }

  lifecycle {
    # Set to true for production — prevents terraform destroy from deleting the instance
    # This is a code-level safeguard in addition to GCP's deletion_protection flag
    prevent_destroy = false

    postcondition {
      condition     = !self.settings[0].ip_configuration[0].ipv4_enabled
      error_message = "Cloud SQL must not have a public IP. Use private networking only."
    }
  }
}

resource "google_sql_database" "this" {
  name     = var.database_name
  project  = var.project_id
  instance = google_sql_database_instance.this.name
}
