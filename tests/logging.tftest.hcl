# Terraform >= 1.7 (or OpenTofu >= 1.7) is required to run these tests, because
# they rely on `mock_provider`. The module itself still only requires >= 1.5.
# No OCI credentials and no network access are needed.

mock_provider "oci" {}

variables {
  compartment_id = "ocid1.compartment.oc1..aaaaaaaaexample"
  display_name   = "unit-test-log-group"
}

run "log_group_only_creates_no_log" {
  assert {
    condition     = length(oci_logging_log.this) == 0
    error_message = "Omitting var.log must create the group alone."
  }
}

run "custom_log_is_enabled_and_retained_by_default" {
  variables {
    log = {
      display_name = "app-custom-log"
    }
  }

  assert {
    condition     = oci_logging_log.this[0].is_enabled == true
    error_message = "A log must default to enabled; a disabled log collects nothing."
  }

  assert {
    condition     = oci_logging_log.this[0].retention_duration == 30
    error_message = "Default retention must be 30 days, a value OCI accepts."
  }

  assert {
    condition     = oci_logging_log.this[0].log_type == "CUSTOM"
    error_message = "Default log_type must be CUSTOM."
  }

  assert {
    condition     = length(oci_logging_log.this[0].configuration) == 0
    error_message = "A CUSTOM log must not carry a service source configuration."
  }
}

run "service_log_wires_its_source_configuration" {
  variables {
    log = {
      display_name       = "vcn-flow-logs"
      log_type           = "SERVICE"
      retention_duration = 90
      source = {
        service  = "flowlogs"
        resource = "ocid1.subnet.oc1..aaaaaaaaexample"
        category = "all"
      }
    }
  }

  assert {
    condition     = length(oci_logging_log.this[0].configuration) == 1
    error_message = "A SERVICE log must emit a configuration block, otherwise it never receives events."
  }

  assert {
    condition     = oci_logging_log.this[0].configuration[0].source[0].service == "flowlogs"
    error_message = "configuration.source.service must come from var.log.source."
  }

  assert {
    condition     = oci_logging_log.this[0].configuration[0].source[0].resource == "ocid1.subnet.oc1..aaaaaaaaexample"
    error_message = "configuration.source.resource must come from var.log.source."
  }

  assert {
    condition     = oci_logging_log.this[0].configuration[0].source[0].category == "all"
    error_message = "configuration.source.category must come from var.log.source."
  }

  assert {
    condition     = oci_logging_log.this[0].configuration[0].source[0].source_type == "OCISERVICE"
    error_message = "configuration.source.source_type must default to OCISERVICE."
  }

  assert {
    condition     = oci_logging_log.this[0].configuration[0].compartment_id == var.compartment_id
    error_message = "configuration.compartment_id must match the module compartment."
  }
}

run "service_log_without_source_is_rejected" {
  command = plan

  variables {
    log = {
      display_name = "vcn-flow-logs"
      log_type     = "SERVICE"
    }
  }

  expect_failures = [var.log]
}

run "custom_log_with_source_is_rejected" {
  command = plan

  variables {
    log = {
      display_name = "app-custom-log"
      log_type     = "CUSTOM"
      source = {
        service  = "flowlogs"
        resource = "ocid1.subnet.oc1..aaaaaaaaexample"
        category = "all"
      }
    }
  }

  expect_failures = [var.log]
}

run "retention_duration_outside_30_day_increments_is_rejected" {
  command = plan

  variables {
    log = {
      display_name       = "app-custom-log"
      retention_duration = 45
    }
  }

  expect_failures = [var.log]
}

run "retention_duration_above_180_is_rejected" {
  command = plan

  variables {
    log = {
      display_name       = "app-custom-log"
      retention_duration = 365
    }
  }

  expect_failures = [var.log]
}

run "unknown_log_type_is_rejected" {
  command = plan

  variables {
    log = {
      display_name = "app-custom-log"
      log_type     = "NotAValidValue"
    }
  }

  expect_failures = [var.log]
}

run "unknown_source_type_is_rejected" {
  command = plan

  variables {
    log = {
      display_name = "vcn-flow-logs"
      log_type     = "SERVICE"
      source = {
        service     = "flowlogs"
        resource    = "ocid1.subnet.oc1..aaaaaaaaexample"
        category    = "all"
        source_type = "SOMETHINGELSE"
      }
    }
  }

  expect_failures = [var.log]
}
