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
