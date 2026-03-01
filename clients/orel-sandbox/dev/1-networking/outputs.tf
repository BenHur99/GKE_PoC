# clients/orel-sandbox/dev/1-networking/outputs.tf

output "vpc_id" {
  description = "The ID of the VPC network"
  value       = module.networking.vpc_id
}

output "vpc_self_link" {
  description = "The self link of the VPC network"
  value       = module.networking.vpc_self_link
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = module.networking.vpc_name
}

output "subnet_ids" {
  description = "Map of subnet name => subnet ID"
  value       = module.networking.subnet_ids
}

output "subnet_self_links" {
  description = "Map of subnet name => subnet self link"
  value       = module.networking.subnet_self_links
}

output "subnet_cidrs" {
  description = "Map of subnet name => primary CIDR"
  value       = module.networking.subnet_cidrs
}

output "gke_subnet_name" {
  description = "Full name of the GKE subnet"
  value       = module.networking.gke_subnet_name
}

output "pod_secondary_range_name" {
  description = "Name of the secondary range for GKE pods"
  value       = module.networking.pod_secondary_range_name
}

output "service_secondary_range_name" {
  description = "Name of the secondary range for GKE services"
  value       = module.networking.service_secondary_range_name
}

output "psa_connection_id" {
  description = "ID of the PSA connection"
  value       = module.networking.psa_connection_id
}

output "router_id" {
  description = "ID of the Cloud Router"
  value       = module.networking.router_id
}

output "nat_id" {
  description = "ID of the Cloud NAT"
  value       = module.networking.nat_id
}
