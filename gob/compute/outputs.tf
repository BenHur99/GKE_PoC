# --- GKE Clusters ---

output "cluster_ids" {
  description = "Map of cluster key => cluster ID"
  value       = { for k, v in module.gke_clusters : k => v.id }
}

output "cluster_names" {
  description = "Map of cluster key => cluster name"
  value       = { for k, v in module.gke_clusters : k => v.name }
}

output "cluster_endpoints" {
  description = "Map of cluster key => API endpoint"
  value       = { for k, v in module.gke_clusters : k => v.endpoint }
}

output "cluster_ca_certificates" {
  description = "Map of cluster key => base64-encoded CA certificate"
  value       = { for k, v in module.gke_clusters : k => v.ca_certificate }
  sensitive   = true
}

output "cluster_master_versions" {
  description = "Map of cluster key => master version"
  value       = { for k, v in module.gke_clusters : k => v.master_version }
}

# --- Node Pools ---

output "node_pool_ids" {
  description = "Map of node pool key => node pool ID"
  value       = { for k, v in module.node_pools : k => v.id }
}

output "node_pool_names" {
  description = "Map of node pool key => node pool name"
  value       = { for k, v in module.node_pools : k => v.name }
}

# --- Naming ---

output "naming_prefix" {
  description = "The computed naming prefix for this environment"
  value       = local.naming_prefix
}
