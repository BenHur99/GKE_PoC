# Read database layer outputs via remote state
data "terraform_remote_state" "database" {
  backend = "gcs"
  config = {
    bucket = "terraform-states-gcs"
    prefix = "${var.client_name}/${var.environment}/database"
  }
}
