# Read networking layer outputs via remote state
data "terraform_remote_state" "networking" {
  backend = "gcs"
  config = {
    bucket = "terraform-states-gcs"
    prefix = "${var.client_name}/${var.environment}/networking"
  }
}
