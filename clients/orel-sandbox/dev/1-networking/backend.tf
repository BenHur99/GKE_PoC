# clients/orel-sandbox/dev/1-networking/backend.tf

terraform {
  backend "gcs" {
    bucket = "terraform-states-gcs"
    prefix = "orel-sandbox/dev/networking"
  }
}
