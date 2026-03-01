# clients/orel-sandbox/dev/1-networking/providers.tf

provider "google" {
  project = var.project_id
  region  = var.region
}
