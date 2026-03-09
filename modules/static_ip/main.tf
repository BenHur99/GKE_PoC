resource "google_compute_address" "this" {
  name         = var.name
  project      = var.project_id
  region       = var.region
  address_type = var.address_type
  network_tier = var.network_tier
}
