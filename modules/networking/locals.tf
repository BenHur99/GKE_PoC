# modules/networking/locals.tf

locals {
  # Filter subnets by purpose for targeted operations
  private_subnets = {
    for k, v in var.subnets : k => v if v.purpose == "PRIVATE"
  }

  # Extract the first subnet that has secondary ranges named "pods" and "services"
  # This is used to output GKE-specific range names for the compute layer
  gke_subnet = one([
    for k, v in var.subnets : {
      name                     = "${var.vpc_name}-${k}"
      pod_secondary_range_name = "${var.vpc_name}-${k}-pods"
      svc_secondary_range_name = "${var.vpc_name}-${k}-services"
    }
    if contains(keys(v.secondary_ranges), "pods") && contains(keys(v.secondary_ranges), "services")
  ])
}
