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

  log_config {
    enable = true
    filter = var.log_filter
  }
}
