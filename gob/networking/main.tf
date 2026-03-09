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
# VPCs
# =============================================================================

module "vpcs" {
  for_each = var.vpcs
  source   = "../../modules/vpc"

  name       = "${local.naming_prefix}-vpc-${each.key}"
  project_id = var.project_id

  depends_on = [module.apis]
}

# =============================================================================
# Subnets
# =============================================================================

module "subnets" {
  for_each = var.subnets
  source   = "../../modules/subnet"

  name                  = "${local.naming_prefix}-subnet-${each.key}"
  project_id            = var.project_id
  region                = var.region
  network_id            = module.vpcs[each.value.vpc_key].id
  cidr                  = each.value.cidr
  purpose               = each.value.purpose
  role                  = each.value.role
  private_google_access = each.value.private_google_access
  secondary_ranges      = each.value.secondary_ranges
}

# =============================================================================
# Firewall Rules
# =============================================================================

module "firewall_rules" {
  for_each = var.firewall_rules
  source   = "../../modules/firewall_rule"

  name               = "${local.naming_prefix}-fw-${each.key}"
  project_id         = var.project_id
  network_id         = module.vpcs[each.value.vpc_key].id
  direction          = each.value.direction
  priority           = each.value.priority
  action             = each.value.action
  protocol           = each.value.protocol
  ports              = each.value.ports
  source_ranges      = each.value.source_ranges
  destination_ranges = each.value.destination_ranges
  target_tags        = each.value.target_tags
  source_tags        = each.value.source_tags
}

# =============================================================================
# Cloud NAT (includes Cloud Router)
# =============================================================================

module "cloud_nats" {
  for_each = var.cloud_nats
  source   = "../../modules/cloud_nat"

  name                               = "${local.naming_prefix}-${each.key}"
  project_id                         = var.project_id
  region                             = var.region
  network_id                         = module.vpcs[each.value.vpc_key].id
  nat_ip_allocate_option             = each.value.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat = each.value.source_subnetwork_ip_ranges_to_nat
  min_ports_per_vm                   = each.value.min_ports_per_vm
  max_ports_per_vm                   = each.value.max_ports_per_vm
  log_filter                         = each.value.log_filter
}

# =============================================================================
# Private Services Access (PSA)
# =============================================================================

module "psa_connections" {
  for_each = var.psa_connections
  source   = "../../modules/psa"

  name       = "${local.naming_prefix}-psa-${each.key}"
  project_id = var.project_id
  network_id = module.vpcs[each.value.vpc_key].id
  cidr       = each.value.cidr

  depends_on = [module.apis]
}

# =============================================================================
# Static IP Addresses
# =============================================================================

module "static_ips" {
  for_each = var.static_ips
  source   = "../../modules/static_ip"

  name         = "${local.naming_prefix}-ip-${each.key}"
  project_id   = var.project_id
  region       = var.region
  address_type = each.value.address_type
  network_tier = each.value.network_tier
}
