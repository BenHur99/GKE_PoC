# =============================================================================
# Identity & Project
# =============================================================================

client_name  = "orel"
product_name = "gob"
environment  = "dev"
project_id   = "orel-bh-sandbox"
region       = "europe-west1"

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
