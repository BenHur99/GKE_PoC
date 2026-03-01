# modules/networking/outputs.tf

# --- VPC ---

output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_self_link" {
  description = "The self link of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

# --- Subnets ---

output "subnet_ids" {
  description = "Map of subnet name => subnet ID"
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.id }
}

output "subnet_self_links" {
  description = "Map of subnet name => subnet self link"
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.self_link }
}

output "subnet_cidrs" {
  description = "Map of subnet name => primary CIDR range"
  value       = { for k, v in google_compute_subnetwork.subnets : k => v.ip_cidr_range }
}

# --- GKE-specific outputs ---

output "gke_subnet_name" {
  description = "The full name of the GKE subnet (for compute layer)"
  value       = local.gke_subnet != null ? local.gke_subnet.name : null
}

output "pod_secondary_range_name" {
  description = "The name of the secondary range for GKE pods"
  value       = local.gke_subnet != null ? local.gke_subnet.pod_secondary_range_name : null
}

output "service_secondary_range_name" {
  description = "The name of the secondary range for GKE services"
  value       = local.gke_subnet != null ? local.gke_subnet.svc_secondary_range_name : null
}

# --- PSA ---

output "psa_connection_id" {
  description = "The ID of the PSA connection (for Cloud SQL dependency)"
  value       = length(google_service_networking_connection.psa) > 0 ? google_service_networking_connection.psa[0].id : null
}

# --- NAT ---

output "router_id" {
  description = "The ID of the Cloud Router"
  value       = length(google_compute_router.router) > 0 ? google_compute_router.router[0].id : null
}

output "nat_id" {
  description = "The ID of the Cloud NAT"
  value       = length(google_compute_router_nat.nat) > 0 ? google_compute_router_nat.nat[0].id : null
}
