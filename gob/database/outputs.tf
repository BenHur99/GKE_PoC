# --- Cloud SQL ---

output "sql_instance_ids" {
  description = "Map of SQL instance key => instance ID"
  value       = { for k, v in module.sql_instances : k => v.instance_id }
}

output "sql_instance_names" {
  description = "Map of SQL instance key => instance name"
  value       = { for k, v in module.sql_instances : k => v.instance_name }
}

output "sql_connection_names" {
  description = "Map of SQL instance key => connection name (project:region:instance)"
  value       = { for k, v in module.sql_instances : k => v.connection_name }
}

output "sql_private_ips" {
  description = "Map of SQL instance key => private IP address"
  value       = { for k, v in module.sql_instances : k => v.private_ip }
}

output "sql_database_names" {
  description = "Map of SQL instance key => database name"
  value       = { for k, v in module.sql_instances : k => v.database_name }
}

# --- Service Accounts ---

output "service_account_emails" {
  description = "Map of SA key => service account email"
  value       = { for k, v in module.service_accounts : k => v.email }
}

output "service_account_ids" {
  description = "Map of SA key => service account ID"
  value       = { for k, v in module.service_accounts : k => v.id }
}

output "service_account_names" {
  description = "Map of SA key => service account fully-qualified name"
  value       = { for k, v in module.service_accounts : k => v.name }
}

# --- Workload Identity Bindings ---

output "wi_binding_ids" {
  description = "Map of WI binding key => IAM binding ID"
  value       = { for k, v in module.wi_bindings : k => v.id }
}

# --- Naming ---

output "naming_prefix" {
  description = "The computed naming prefix for this environment"
  value       = local.naming_prefix
}
