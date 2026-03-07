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
# Workload Identity Federation Pools
# =============================================================================

module "wif_pools" {
  for_each = var.wif_pools
  source   = "../../modules/wif_pool"

  name                = "${local.naming_prefix}-wip-${each.key}"
  project_id          = var.project_id
  display_name        = each.value.display_name
  provider_id         = each.value.provider_id
  issuer_uri          = each.value.issuer_uri
  attribute_mapping   = each.value.attribute_mapping
  attribute_condition = each.value.attribute_condition

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
# Service Networking Agent - required for PSA peering in networking layer
# =============================================================================

resource "google_project_iam_member" "servicenetworking_agent" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:service-${data.google_project.this.number}@service-networking.iam.gserviceaccount.com"
}

# =============================================================================
# WIF → Service Account Bindings (allow GitHub to impersonate GSA)
# =============================================================================

resource "google_service_account_iam_member" "wif_sa_binding" {
  for_each = var.service_accounts

  service_account_id = module.service_accounts[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${module.wif_pools[each.value.wif_pool_key].pool_name}/attribute.repository/${each.value.github_repo}"
}
