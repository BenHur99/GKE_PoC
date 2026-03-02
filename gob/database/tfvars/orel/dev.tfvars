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
    deletion_protection = false
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
