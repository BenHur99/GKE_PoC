# --- VPCs ---

output "vpc_ids" {
  description = "Map of VPC key => VPC ID"
  value       = { for k, v in module.vpcs : k => v.id }
}

output "vpc_self_links" {
  description = "Map of VPC key => VPC self link"
  value       = { for k, v in module.vpcs : k => v.self_link }
}

output "vpc_names" {
  description = "Map of VPC key => VPC name"
  value       = { for k, v in module.vpcs : k => v.name }
}

# --- Subnets ---

output "subnet_ids" {
  description = "Map of subnet key => subnet ID"
  value       = { for k, v in module.subnets : k => v.id }
}

output "subnet_self_links" {
  description = "Map of subnet key => subnet self link"
  value       = { for k, v in module.subnets : k => v.self_link }
}

output "subnet_names" {
  description = "Map of subnet key => subnet name"
  value       = { for k, v in module.subnets : k => v.name }
}

output "subnet_cidrs" {
  description = "Map of subnet key => subnet primary CIDR"
  value       = { for k, v in module.subnets : k => v.cidr }
}

output "subnet_secondary_range_names" {
  description = "Map of subnet key => map of secondary range key => range name"
  value       = { for k, v in module.subnets : k => v.secondary_range_names }
}

# --- Cloud NAT ---

output "cloud_nat_router_ids" {
  description = "Map of NAT key => Cloud Router ID"
  value       = { for k, v in module.cloud_nats : k => v.router_id }
}

output "cloud_nat_ids" {
  description = "Map of NAT key => Cloud NAT ID"
  value       = { for k, v in module.cloud_nats : k => v.nat_id }
}

# --- PSA ---

output "psa_connection_ids" {
  description = "Map of PSA key => connection ID"
  value       = { for k, v in module.psa_connections : k => v.connection_id }
}

# --- Naming ---

output "naming_prefix" {
  description = "The computed naming prefix for this environment"
  value       = local.naming_prefix
}
