run "standard_naming" {
  command = plan

  variables {
    client_name  = "acme"
    product_name = "web"
    environment  = "dev"
    region       = "europe-west1"
    layer        = "networking"
  }

  assert {
    condition     = output.prefix == "acme-web-dev-euw1"
    error_message = "Naming prefix should be acme-web-dev-euw1, got ${output.prefix}"
  }

  assert {
    condition     = output.region_short == "euw1"
    error_message = "Region short should be euw1, got ${output.region_short}"
  }

  assert {
    condition     = output.common_labels["client"] == "acme"
    error_message = "Label client should be acme"
  }

  assert {
    condition     = output.common_labels["managed_by"] == "terraform"
    error_message = "Label managed_by should be terraform"
  }
}

run "us_region_naming" {
  command = plan

  variables {
    client_name  = "orel"
    product_name = "gob"
    environment  = "prod"
    region       = "us-central1"
    layer        = "compute"
  }

  assert {
    condition     = output.prefix == "orel-gob-prod-usc1"
    error_message = "Naming prefix should be orel-gob-prod-usc1, got ${output.prefix}"
  }
}

run "unknown_region_fallback" {
  command = plan

  variables {
    client_name  = "test"
    product_name = "app"
    environment  = "dev"
    region       = "southamerica-east1"
    layer        = "networking"
  }

  assert {
    condition     = output.region_short == "southamericaeast1"
    error_message = "Unknown region should fallback to dashes-removed format"
  }
}
