resource "google_service_account" "this" {
  account_id   = var.name
  project      = var.project_id
  display_name = var.display_name
  description  = var.description
}

resource "google_project_iam_member" "this" {
  for_each = toset(var.roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}
