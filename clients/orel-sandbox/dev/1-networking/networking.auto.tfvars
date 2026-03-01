# clients/orel-sandbox/dev/1-networking/networking.auto.tfvars

# =============================================================================
# Project Configuration
# =============================================================================

project_id = "orel-bh-sandbox"
region     = "europe-west1"
vpc_name   = "orel-sandbox-dev"

# =============================================================================
# APIs to Enable
# =============================================================================

apis = [
  "compute.googleapis.com",
  "container.googleapis.com",
  "servicenetworking.googleapis.com",
  "sqladmin.googleapis.com",
]

# =============================================================================
# Subnets
# =============================================================================

subnets = {
  "gke-subnet" = {
    cidr = "10.0.0.0/20"
    secondary_ranges = {
      "pods"     = { cidr = "10.4.0.0/14" }
      "services" = { cidr = "10.8.0.0/20" }
    }
  }
  "proxy-only-subnet" = {
    cidr    = "10.0.16.0/23"
    purpose = "REGIONAL_MANAGED_PROXY"
    role    = "ACTIVE"
  }
}

# =============================================================================
# Firewall Rules (deny-all + explicit whitelist)
# =============================================================================

firewall_rules = {
  "deny-all-ingress" = {
    action        = "deny"
    protocol      = "all"
    priority      = 65534
    source_ranges = ["0.0.0.0/0"]
  }

  "allow-iap-ssh" = {
    action        = "allow"
    protocol      = "tcp"
    ports         = ["22"]
    source_ranges = ["35.235.240.0/20"]
  }

  "allow-health-checks" = {
    action        = "allow"
    protocol      = "tcp"
    ports         = ["80", "443", "8080"]
    source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
    target_tags   = ["gke-node"]
  }

  "allow-proxy-to-backends" = {
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

nat_config = {
  min_ports_per_vm = 64
  max_ports_per_vm = 4096
  log_filter       = "ERRORS_ONLY"
}

# =============================================================================
# Private Services Access (for Cloud SQL)
# =============================================================================

psa_ranges = {
  "google-managed-services" = {
    cidr = "10.16.0.0/16"
  }
}
