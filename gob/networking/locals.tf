locals {
  naming_prefix = module.naming.prefix

  # Resolve "gke-node" sentinel in firewall target_tags to the env-scoped tag.
  # This ensures FW rules are isolated per client/product/env without hardcoding
  # the tag value in tfvars (which can't reference module outputs).
  firewall_rules_resolved = {
    for k, v in var.firewall_rules : k => merge(v, {
      target_tags = [
        for tag in v.target_tags :
        tag == "gke-node" ? module.naming.gke_node_tag : tag
      ]
    })
  }
}
