locals {
  # Region short name mapping for resource naming
  region_short_map = {
    "europe-west1"    = "euw1"
    "europe-west2"    = "euw2"
    "europe-west3"    = "euw3"
    "us-central1"     = "usc1"
    "us-east1"        = "use1"
    "us-west1"        = "usw1"
    "asia-east1"      = "ase1"
    "asia-southeast1" = "asse1"
  }

  region_short = lookup(local.region_short_map, var.region, replace(replace(replace(var.region, "europe-", "eu"), "us-", "us"), "asia-", "as"))

  # Unified naming prefix: {client}-{product}-{env}-{region_short}
  naming_prefix = "${var.client_name}-${var.product_name}-${var.environment}-${local.region_short}"
}
