output "address_id" {
  description = "Global address allocation ID"
  value       = google_compute_global_address.this.id
}

output "connection_id" {
  description = "Service networking connection ID"
  value       = google_service_networking_connection.this.id
}
