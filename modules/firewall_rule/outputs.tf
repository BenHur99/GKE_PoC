output "id" {
  description = "Firewall rule ID"
  value       = google_compute_firewall.this.id
}

output "name" {
  description = "Firewall rule name"
  value       = google_compute_firewall.this.name
}
