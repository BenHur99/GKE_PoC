mock_provider "google" {}

run "invalid_direction" {
  command = plan

  variables {
    name       = "test-fw"
    project_id = "test-project"
    network_id = "projects/test/global/networks/test"
    direction  = "INVALID"
    action     = "allow"
    protocol   = "tcp"
  }

  expect_failures = [var.direction]
}

run "invalid_action" {
  command = plan

  variables {
    name       = "test-fw"
    project_id = "test-project"
    network_id = "projects/test/global/networks/test"
    direction  = "INGRESS"
    action     = "permit"
    protocol   = "tcp"
  }

  expect_failures = [var.action]
}

run "invalid_protocol" {
  command = plan

  variables {
    name       = "test-fw"
    project_id = "test-project"
    network_id = "projects/test/global/networks/test"
    direction  = "INGRESS"
    action     = "allow"
    protocol   = "http"
  }

  expect_failures = [var.protocol]
}

run "invalid_priority" {
  command = plan

  variables {
    name       = "test-fw"
    project_id = "test-project"
    network_id = "projects/test/global/networks/test"
    direction  = "INGRESS"
    action     = "allow"
    protocol   = "tcp"
    priority   = 70000
  }

  expect_failures = [var.priority]
}
