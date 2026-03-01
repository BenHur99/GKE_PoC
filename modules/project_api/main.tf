resource "google_project_service" "this" {
  project            = var.project_id
  service            = var.api
  disable_on_destroy = false
}
