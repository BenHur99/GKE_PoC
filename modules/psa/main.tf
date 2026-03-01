resource "google_compute_global_address" "this" {
  name          = var.name
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = tonumber(split("/", var.cidr)[1])
  address       = split("/", var.cidr)[0]
  network       = var.network_id
}

resource "google_service_networking_connection" "this" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.this.name]
}
