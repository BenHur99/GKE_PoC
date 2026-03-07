# No remote state dependencies - automation layer is independent

data "google_project" "this" {
  project_id = var.project_id
}
