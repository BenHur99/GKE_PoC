resource "google_compute_router" "this" {
  name    = "${var.name}-router"
  project = var.project_id
  region  = var.region
  network = var.network_id
}

resource "google_compute_router_nat" "this" {
  name                               = "${var.name}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = var.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = var.source_subnetwork_ip_ranges_to_nat
  min_ports_per_vm                   = var.min_ports_per_vm
  max_ports_per_vm                   = var.max_ports_per_vm

  lifecycle {
    precondition {
      condition     = var.source_subnetwork_ip_ranges_to_nat != "LIST_OF_SUBNETWORKS" || length(var.subnetworks) > 0
      error_message = "When source_subnetwork_ip_ranges_to_nat is LIST_OF_SUBNETWORKS, at least one subnetwork must be provided."
    }
  }

  dynamic "subnetwork" {
    for_each = var.subnetworks
    content {
      name                    = subnetwork.value.name
      source_ip_ranges_to_nat = subnetwork.value.source_ip_ranges_to_nat
    }
  }

  log_config {
    enable = true
    filter = var.log_filter
  }
}
