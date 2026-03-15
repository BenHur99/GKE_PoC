output "instance_id" {
  description = "Cloud SQL instance ID"
  value       = google_sql_database_instance.this.id
}

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Cloud SQL connection name (project:region:instance) - used by Cloud SQL Proxy"
  value       = google_sql_database_instance.this.connection_name
  sensitive   = true
}

output "private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.this.private_ip_address
  sensitive   = true
}

output "database_name" {
  description = "Name of the database created"
  value       = google_sql_database.this.name
}
