resource "google_container_node_pool" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location
  cluster  = var.cluster_name

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = var.auto_repair
    auto_upgrade = var.auto_upgrade
  }

  node_config {
    machine_type = var.machine_type
    spot         = var.spot
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    oauth_scopes = var.oauth_scopes
    image_type   = var.image_type
    service_account = var.service_account != "" ? var.service_account : null

    # Required for Workload Identity on nodes — tells kubelet to use GKE metadata server
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    resource_labels = var.labels
    tags            = var.network_tags
  }
}
