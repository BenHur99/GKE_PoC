output "id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.this.id
}

output "name" {
  description = "GKE cluster name"
  value       = google_container_cluster.this.name
}

output "endpoint" {
  description = "GKE cluster API endpoint"
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster"
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "master_version" {
  description = "Current master version of the cluster"
  value       = google_container_cluster.this.master_version
}
