# =============================================================================
# Identity & Project
# =============================================================================

client_name  = "orel"
product_name = "gob"
environment  = "dev"
project_id   = "orel-bh-sandbox"
region       = "europe-west1"

# =============================================================================
# APIs
# =============================================================================

apis = [
  "iam.googleapis.com",
  "iamcredentials.googleapis.com",
  "sts.googleapis.com",
  "cloudresourcemanager.googleapis.com",
]

# =============================================================================
# WIF Pools
# =============================================================================

wif_pools = {
  "github" = {
    display_name = "GitHub Actions Pool"
    provider_id  = "orel-gob-dev-euw1-gha"
    issuer_uri   = "https://token.actions.githubusercontent.com"
    attribute_condition = "assertion.repository_owner == \"BenHur99\""
    attribute_mapping = {
      "google.subject"             = "assertion.sub"
      "attribute.actor"            = "assertion.actor"
      "attribute.repository"       = "assertion.repository"
      "attribute.repository_owner" = "assertion.repository_owner"
    }
  }
}

# =============================================================================
# Service Accounts
# =============================================================================

service_accounts = {
  "cicd" = {
    display_name = "CI/CD GitHub Actions"
    description  = "SA for GitHub Actions WIF-based deployment"
    # Least-privilege roles for CI/CD pipeline operations.
    # Each role scoped to what terraform apply/destroy needs.
    roles = [
      "roles/container.admin",
      "roles/compute.admin",
      "roles/cloudsql.admin",
      "roles/storage.admin",
      "roles/servicenetworking.networksAdmin",
      "roles/resourcemanager.projectIamAdmin",
      "roles/iam.serviceAccountAdmin"
    ]
    wif_pool_key = "github"
    github_repo  = "BenHur99/GKE_PoC"
  }
}
