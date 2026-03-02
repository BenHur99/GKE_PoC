output "id" {
  description = "Service account ID"
  value       = google_service_account.this.id
}

output "email" {
  description = "Service account email"
  value       = google_service_account.this.email
}

output "name" {
  description = "Service account fully-qualified name"
  value       = google_service_account.this.name
}
