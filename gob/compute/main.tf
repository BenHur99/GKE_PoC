# =============================================================================
# Naming
# =============================================================================

module "naming" {
  source       = "../../modules/naming"
  client_name  = var.client_name
  product_name = var.product_name
  environment  = var.environment
  region       = var.region
}

# =============================================================================
# APIs
# =============================================================================

module "apis" {
  for_each = toset(var.apis)
  source   = "../../modules/project_api"

  project_id = var.project_id
  api        = each.value
}

# =============================================================================
# GKE Clusters
# =============================================================================

module "gke_clusters" {
  for_each = var.gke_clusters
  source   = "../../modules/gke_cluster"

  name       = "${local.naming_prefix}-gke-${each.key}"
  project_id = var.project_id
  location   = each.value.zone

  network_id                    = data.terraform_remote_state.networking.outputs.vpc_self_links[each.value.vpc_key]
  subnet_id                     = data.terraform_remote_state.networking.outputs.subnet_self_links[each.value.subnet_key]
  pods_secondary_range_name     = data.terraform_remote_state.networking.outputs.subnet_secondary_range_names[each.value.subnet_key][each.value.pods_secondary_range_key]
  services_secondary_range_name = data.terraform_remote_state.networking.outputs.subnet_secondary_range_names[each.value.subnet_key][each.value.services_secondary_range_key]

  master_ipv4_cidr_block     = each.value.master_ipv4_cidr_block
  release_channel            = each.value.release_channel
  workload_identity_enabled  = each.value.workload_identity_enabled
  deletion_protection        = each.value.deletion_protection
  gateway_api_enabled        = each.value.gateway_api_enabled
  master_authorized_networks = each.value.master_authorized_networks

  depends_on = [module.apis]
}

# =============================================================================
# Node Pools
# =============================================================================

module "node_pools" {
  for_each = var.node_pools
  source   = "../../modules/gke_node_pool"

  name         = "${local.naming_prefix}-gke-${each.value.cluster_key}-${each.key}"
  project_id   = var.project_id
  location     = var.gke_clusters[each.value.cluster_key].zone
  cluster_name = module.gke_clusters[each.value.cluster_key].name

  machine_type   = each.value.machine_type
  spot           = each.value.spot
  min_node_count = each.value.min_node_count
  max_node_count = each.value.max_node_count
  disk_size_gb   = each.value.disk_size_gb
  disk_type      = each.value.disk_type
  auto_repair    = each.value.auto_repair
  auto_upgrade   = each.value.auto_upgrade
  oauth_scopes   = each.value.oauth_scopes
}
