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
  "container.googleapis.com",
]

# =============================================================================
# GKE Clusters
# =============================================================================

gke_clusters = {
  "main" = {
    subnet_key             = "gke"
    zone                   = "europe-west1-b"
    master_ipv4_cidr_block = "172.16.0.0/28"
    release_channel        = "REGULAR"
    # DEV ONLY: Open to all IPs for ephemeral development environment.
    # For staging/prod: restrict to office IPs, VPN ranges, and CI/CD runner IPs.
    master_authorized_networks = {
      "allow-all" = {
        cidr_block = "0.0.0.0/0"
      }
    }
  }
}

# =============================================================================
# Node Pools
# =============================================================================

node_pools = {
  "spot" = {
    cluster_key    = "main"
    machine_type   = "e2-medium"
    spot           = true
    min_node_count = 1
    max_node_count = 3
    disk_size_gb   = 50
  }
}
