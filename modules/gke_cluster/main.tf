resource "google_container_cluster" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location

  network    = var.network_id
  subnetwork = var.subnet_id

  # Remove the default node pool — we manage node pools as separate resources
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.deletion_protection

  # VPC-native networking using subnet secondary ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  # Private cluster: nodes get private IPs only, control plane endpoint stays public
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Master Authorized Networks — dynamic block, varies per client/environment
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          display_name = cidr_blocks.key
          cidr_block   = cidr_blocks.value.cidr_block
        }
      }
    }
  }

  # Workload Identity — enables secure KSA-to-GSA binding (configured in Stage 4)
  dynamic "workload_identity_config" {
    for_each = var.workload_identity_enabled ? [1] : []
    content {
      workload_pool = "${var.project_id}.svc.id.goog"
    }
  }

  # Release channel controls automatic version upgrades
  release_channel {
    channel = var.release_channel
  }

  # Gateway API — enables gateway.networking.k8s.io CRDs managed by GKE
  dynamic "gateway_api_config" {
    for_each = var.gateway_api_enabled ? [1] : []
    content {
      channel = "CHANNEL_STANDARD"
    }
  }
}
