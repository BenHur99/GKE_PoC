locals {
  region_short_map = {
    "europe-west1"         = "euw1"
    "europe-west2"         = "euw2"
    "europe-west3"         = "euw3"
    "us-central1"          = "usc1"
    "us-east1"             = "use1"
    "us-east4"             = "use4"
    "us-west1"             = "usw1"
    "me-west1"             = "mew1"
    "asia-east1"           = "ase1"
    "asia-southeast1"      = "asse1"
    "australia-southeast1" = "ause1"
  }

  region_short = lookup(local.region_short_map, var.region, replace(var.region, "-", ""))
  prefix       = "${var.client_name}-${var.product_name}-${var.environment}-${local.region_short}"

  common_labels = merge({
    client      = var.client_name
    product     = var.product_name
    environment = var.environment
    region      = local.region_short
    managed_by  = "terraform"
    layer       = var.layer
  }, var.extra_labels)

  gke_node_tag = "${var.client_name}-${var.product_name}-${var.environment}-gke-node"
}
