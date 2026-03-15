# =============================================================================
# Naming
# =============================================================================

module "naming" {
  source       = "../../modules/naming"
  client_name  = var.client_name
  product_name = var.product_name
  environment  = var.environment
  region       = var.region
  layer        = "database"
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
# Cloud SQL Instances
# =============================================================================

module "sql_instances" {
  for_each = var.sql_instances
  source   = "../../modules/cloud_sql"

  name                = "${local.naming_prefix}-sql-${each.key}"
  project_id          = var.project_id
  region              = var.region
  database_version    = each.value.database_version
  tier                = each.value.tier
  disk_size           = each.value.disk_size
  disk_type           = each.value.disk_type
  availability_type   = each.value.availability_type
  network_id          = data.terraform_remote_state.networking.outputs.vpc_self_links[each.value.vpc_key]
  database_name       = each.value.database_name
  database_flags      = each.value.database_flags
  deletion_protection = each.value.deletion_protection
  backup_enabled      = each.value.backup_enabled
  backup_start_time   = each.value.backup_start_time
  labels              = module.naming.common_labels

  depends_on = [module.apis]
}

# =============================================================================
# Service Accounts
# =============================================================================

module "service_accounts" {
  for_each = var.service_accounts
  source   = "../../modules/service_account"

  name         = "${local.naming_prefix}-sa-${each.key}"
  project_id   = var.project_id
  display_name = each.value.display_name
  description  = each.value.description
  roles        = each.value.roles
}

# =============================================================================
# Workload Identity Bindings (KSA -> GSA)
# =============================================================================

module "wi_bindings" {
  for_each = var.wi_bindings
  source   = "../../modules/wi_binding"

  gsa_name      = module.service_accounts[each.value.gsa_key].name
  project_id    = var.project_id
  k8s_namespace = each.value.k8s_namespace
  ksa_name      = each.value.ksa_name

  depends_on = [module.service_accounts]
}
