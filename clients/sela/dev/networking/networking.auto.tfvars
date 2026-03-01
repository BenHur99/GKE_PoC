# =============================================================================
# Identity & Project
# =============================================================================

client_name  = "sela"
product_name = "gob"
environment  = "dev"
project_id   = "orel-bh-sandbox"
region       = "europe-west1"

# =============================================================================
# APIs
# =============================================================================

apis = [
  "compute.googleapis.com",
  "container.googleapis.com",
  "servicenetworking.googleapis.com",
  "sqladmin.googleapis.com",
]

# =============================================================================
# VPCs
# =============================================================================

vpcs = {
  "main" = {}
}

# =============================================================================
# Subnets
# =============================================================================

subnets = {
  "gke" = {
    vpc_key = "main"
    cidr    = "10.0.0.0/20"
    secondary_ranges = {
      "pods"     = { cidr = "10.4.0.0/14" }
      "services" = { cidr = "10.8.0.0/20" }
    }
  }
  "proxy" = {
    vpc_key = "main"
    cidr    = "10.0.16.0/23"
    purpose = "REGIONAL_MANAGED_PROXY"
    role    = "ACTIVE"
  }
}

# =============================================================================
# Firewall Rules
# =============================================================================

firewall_rules = {
  "deny-all-ingress" = {
    vpc_key       = "main"
    action        = "deny"
    protocol      = "all"
    priority      = 65534
    source_ranges = ["0.0.0.0/0"]
  }
  "allow-iap-ssh" = {
    vpc_key       = "main"
    action        = "allow"
    protocol      = "tcp"
    ports         = ["22"]
    source_ranges = ["35.235.240.0/20"]
  }
  "allow-health-checks" = {
    vpc_key       = "main"
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
    target_tags   = ["gke-node"]
  }
  "allow-proxy-to-backends" = {
    vpc_key       = "main"
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["10.0.16.0/23"]
    target_tags   = ["gke-node"]
  }
}

# =============================================================================
# Cloud NAT
# =============================================================================

cloud_nats = {
  "main" = {
    vpc_key = "main"
  }
}

# =============================================================================
# Private Services Access (for Cloud SQL)
# =============================================================================

psa_connections = {
  "google-managed" = {
    vpc_key = "main"
    cidr    = "10.16.0.0/16"
  }
}
