output "id" {
  description = "VPC network ID"
  value       = google_compute_network.this.id
}

output "self_link" {
  description = "VPC network self link"
  value       = google_compute_network.this.self_link
}

output "name" {
  description = "VPC network name"
  value       = google_compute_network.this.name
}
