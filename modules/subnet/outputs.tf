output "id" {
  description = "Subnet ID"
  value       = google_compute_subnetwork.this.id
}

output "self_link" {
  description = "Subnet self link"
  value       = google_compute_subnetwork.this.self_link
}

output "name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.this.name
}

output "cidr" {
  description = "Subnet primary CIDR"
  value       = google_compute_subnetwork.this.ip_cidr_range
}

output "secondary_range_names" {
  description = "Map of secondary range key => full range name (for GKE cluster config)"
  value       = { for k, v in var.secondary_ranges : k => "${var.name}-${k}" }
}
