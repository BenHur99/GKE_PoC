# =============================================================================
# Workload Identity Bindings (KSA -> GSA)
# =============================================================================

module "wi_bindings" {
  for_each = var.wi_bindings
  source   = "../../modules/wi_binding"

  gsa_name      = data.terraform_remote_state.database.outputs.service_account_names[each.value.gsa_key]
  project_id    = var.project_id
  k8s_namespace = each.value.k8s_namespace
  ksa_name      = each.value.ksa_name
}
