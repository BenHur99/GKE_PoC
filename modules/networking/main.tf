# modules/networking/main.tf

# =============================================================================
# API Enablement
# =============================================================================

resource "google_project_service" "apis" {
  for_each = toset(var.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# =============================================================================
# VPC Network
# =============================================================================

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.apis]
}

# =============================================================================
# Subnets (for_each on var.subnets)
# =============================================================================

resource "google_compute_subnetwork" "subnets" {
  for_each = var.subnets

  name          = "${var.vpc_name}-${each.key}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = each.value.cidr
  purpose       = each.value.purpose
  role          = each.value.role

  private_ip_google_access = each.value.purpose == "PRIVATE" ? each.value.private_google_access : null

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges

    content {
      range_name    = "${var.vpc_name}-${each.key}-${secondary_ip_range.key}"
      ip_cidr_range = secondary_ip_range.value.cidr
    }
  }
}

# =============================================================================
# Firewall Rules (for_each on var.firewall_rules)
# =============================================================================

resource "google_compute_firewall" "rules" {
  for_each = var.firewall_rules

  name      = "${var.vpc_name}-${each.key}"
  project   = var.project_id
  network   = google_compute_network.vpc.id
  direction = each.value.direction
  priority  = each.value.priority

  source_ranges      = each.value.direction == "INGRESS" ? each.value.source_ranges : null
  destination_ranges = each.value.direction == "EGRESS" ? each.value.destination_ranges : null
  target_tags        = length(each.value.target_tags) > 0 ? each.value.target_tags : null
  source_tags        = each.value.direction == "INGRESS" && length(each.value.source_tags) > 0 ? each.value.source_tags : null

  dynamic "allow" {
    for_each = each.value.action == "allow" ? [1] : []

    content {
      protocol = each.value.protocol
      ports    = length(each.value.ports) > 0 ? each.value.ports : null
    }
  }

  dynamic "deny" {
    for_each = each.value.action == "deny" ? [1] : []

    content {
      protocol = each.value.protocol
      ports    = length(each.value.ports) > 0 ? each.value.ports : null
    }
  }
}

# =============================================================================
# Cloud Router + Cloud NAT
# =============================================================================

resource "google_compute_router" "router" {
  count = var.nat_config != null ? 1 : 0

  name    = "${var.vpc_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  count = var.nat_config != null ? 1 : 0

  name                               = "${var.vpc_name}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.router[0].name
  nat_ip_allocate_option             = var.nat_config.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = var.nat_config.source_subnetwork_ip_ranges_to_nat
  min_ports_per_vm                   = var.nat_config.min_ports_per_vm
  max_ports_per_vm                   = var.nat_config.max_ports_per_vm

  log_config {
    enable = true
    filter = var.nat_config.log_filter
  }
}

# =============================================================================
# Private Services Access (PSA)
# =============================================================================

resource "google_compute_global_address" "psa" {
  for_each = var.psa_ranges

  name          = "${var.vpc_name}-${each.key}"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = tonumber(split("/", each.value.cidr)[1])
  address       = split("/", each.value.cidr)[0]
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "psa" {
  count = length(var.psa_ranges) > 0 ? 1 : 0

  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [for k, v in google_compute_global_address.psa : v.name]

  depends_on = [google_project_service.apis]
}
