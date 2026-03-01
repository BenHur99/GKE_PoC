terraform {
  backend "gcs" {
    bucket = "terraform-states-gcs"
    prefix = "sela/dev/networking"
  }
}
