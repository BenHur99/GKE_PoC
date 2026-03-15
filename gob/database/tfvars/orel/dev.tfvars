# =============================================================================
# Identity & Project
# =============================================================================

client_name  = "orel"
product_name = "gob"
environment  = "dev"
project_id   = "orel-bh-sandbox"
region       = "europe-west1"

# =============================================================================
# APIs
# =============================================================================

apis = [
  "sqladmin.googleapis.com",
]

# =============================================================================
# Cloud SQL Instances
# =============================================================================

sql_instances = {
  "main" = {
    database_version    = "POSTGRES_15"
    tier                = "db-f1-micro"
    disk_size           = 10
    disk_type           = "PD_HDD"
    availability_type   = "ZONAL"
    database_name       = "boutique"
    # DEV ONLY: Disabled for easy teardown of ephemeral environment.
    # For staging/prod: set to true to prevent accidental data loss.
    deletion_protection = false
    # DEV: Backups disabled to save cost on ephemeral environment.
    # For staging/prod: set backup_enabled = true, backup_start_time = "03:00"
    database_flags = {
      "cloudsql.iam_authentication" = "on"
    }
  }
}

# =============================================================================
# Service Accounts
# =============================================================================

service_accounts = {
  "btq-sql" = {
    display_name = "Boutique Cloud SQL Client"
    description  = "GSA for Online Boutique application - Cloud SQL IAM authentication"
    roles        = ["roles/cloudsql.client"]
  }
}

# =============================================================================
# Workload Identity Bindings
# =============================================================================

wi_bindings = {
  "sql-proxy" = {
    gsa_key       = "btq-sql"
    k8s_namespace = "boutique"
    ksa_name      = "boutique-sql-proxy"
  }
}
