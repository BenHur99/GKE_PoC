resource "google_compute_firewall" "this" {
  name      = var.name
  project   = var.project_id
  network   = var.network_id
  direction = var.direction
  priority  = var.priority

  source_ranges      = var.direction == "INGRESS" && length(var.source_ranges) > 0 ? var.source_ranges : null
  destination_ranges = var.direction == "EGRESS" && length(var.destination_ranges) > 0 ? var.destination_ranges : null
  target_tags        = length(var.target_tags) > 0 ? var.target_tags : null
  source_tags        = var.direction == "INGRESS" && length(var.source_tags) > 0 ? var.source_tags : null

  dynamic "allow" {
    for_each = var.action == "allow" ? [1] : []

    content {
      protocol = var.protocol
      ports    = length(var.ports) > 0 ? var.ports : null
    }
  }

  dynamic "deny" {
    for_each = var.action == "deny" ? [1] : []

    content {
      protocol = var.protocol
      ports    = length(var.ports) > 0 ? var.ports : null
    }
  }
}
