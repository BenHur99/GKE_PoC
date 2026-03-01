resource "google_compute_network" "this" {
  name                    = var.name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}
