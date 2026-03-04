# --- WIF Pools ---

output "wif_pool_ids" {
  description = "Map of WIF pool key => pool ID"
  value       = { for k, v in module.wif_pools : k => v.pool_id }
}

output "wif_pool_names" {
  description = "Map of WIF pool key => pool full resource name"
  value       = { for k, v in module.wif_pools : k => v.pool_name }
}

output "wif_provider_names" {
  description = "Map of WIF pool key => provider full resource name"
  value       = { for k, v in module.wif_pools : k => v.provider_name }
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

# --- Naming ---

output "naming_prefix" {
  description = "The computed naming prefix for this environment"
  value       = local.naming_prefix
}
