output "id" {
  description = "Static IP address resource ID"
  value       = google_compute_address.this.id
}

output "address" {
  description = "The reserved IP address"
  value       = google_compute_address.this.address
}

output "self_link" {
  description = "Static IP address self link"
  value       = google_compute_address.this.self_link
}

output "name" {
  description = "Static IP address resource name"
  value       = google_compute_address.this.name
}
