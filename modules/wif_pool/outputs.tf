output "pool_id" {
  description = "Workload Identity Pool ID"
  value       = google_iam_workload_identity_pool.this.id
}

output "pool_name" {
  description = "Workload Identity Pool full resource name"
  value       = google_iam_workload_identity_pool.this.name
}

output "provider_id" {
  description = "Workload Identity Pool Provider ID"
  value       = google_iam_workload_identity_pool_provider.this.id
}

output "provider_name" {
  description = "Workload Identity Pool Provider full resource name"
  value       = google_iam_workload_identity_pool_provider.this.name
}
