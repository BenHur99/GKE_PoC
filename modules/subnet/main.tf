resource "google_compute_subnetwork" "this" {
  name          = var.name
  project       = var.project_id
  region        = var.region
  network       = var.network_id
  ip_cidr_range = var.cidr
  purpose       = var.purpose
  role          = var.role

  private_ip_google_access = var.purpose == "PRIVATE" ? var.private_google_access : null

  dynamic "secondary_ip_range" {
    for_each = var.secondary_ranges

    content {
      range_name    = "${var.name}-${secondary_ip_range.key}"
      ip_cidr_range = secondary_ip_range.value.cidr
    }
  }
}
