terraform {
  backend "gcs" {
    bucket = "terraform-states-gcs"
    # prefix is set dynamically via: terraform init -backend-config="prefix=CLIENT/ENV/LAYER"
  }
}
