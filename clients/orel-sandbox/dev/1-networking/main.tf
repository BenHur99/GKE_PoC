# clients/orel-sandbox/dev/1-networking/main.tf

module "networking" {
  source = "../../../../modules/networking"

  project_id     = var.project_id
  region         = var.region
  vpc_name       = var.vpc_name
  apis           = var.apis
  subnets        = var.subnets
  firewall_rules = var.firewall_rules
  nat_config     = var.nat_config
  psa_ranges     = var.psa_ranges
}
