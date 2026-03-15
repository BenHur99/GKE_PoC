mock_provider "google" {}

run "invalid_address_type" {
  command = plan

  variables {
    name         = "test-ip"
    project_id   = "test-project"
    region       = "europe-west1"
    address_type = "PUBLIC"
  }

  expect_failures = [var.address_type]
}

run "invalid_network_tier" {
  command = plan

  variables {
    name         = "test-ip"
    project_id   = "test-project"
    region       = "europe-west1"
    network_tier = "BASIC"
  }

  expect_failures = [var.network_tier]
}
