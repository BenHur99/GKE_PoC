resource "google_compute_network" "this" {
  name                    = var.name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  lifecycle {
    # Set to true for production — prevents accidental VPC deletion (cascading subnet/firewall loss)
    prevent_destroy = false

    postcondition {
      condition     = !self.auto_create_subnetworks
      error_message = "VPC must not auto-create subnetworks. Use explicit subnet modules."
    }
  }
}
