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

run "no_logs_map_by_default" {
  command = plan

  assert {
    condition     = length(oci_logging_log.logs) == 0
    error_message = "var.logs must default to creating no logs."
  }
}

run "several_logs_in_one_group" {
  variables {
    logs = {
      lb-access = {
        log_type = "SERVICE"
        source = {
          service  = "loadbalancer"
          resource = "ocid1.loadbalancer.oc1..aaaaaaaaexample"
          category = "access"
        }
      }
      lb-error = {
        display_name       = "load-balancer-errors"
        log_type           = "SERVICE"
        retention_duration = 90
        source = {
          service  = "loadbalancer"
          resource = "ocid1.loadbalancer.oc1..aaaaaaaaexample"
          category = "error"
        }
      }
      app = {}
    }
  }

  assert {
    condition     = length(oci_logging_log.logs) == 3 && length(oci_logging_log.this) == 0
    error_message = "One log per var.logs entry must be created, and no single log without var.log."
  }

  assert {
    condition     = alltrue([for l in oci_logging_log.logs : l.log_group_id == oci_logging_log_group.this.id])
    error_message = "Every log must be created in the module's log group."
  }

  assert {
    condition     = oci_logging_log.logs["lb-access"].display_name == "lb-access" && oci_logging_log.logs["lb-error"].display_name == "load-balancer-errors"
    error_message = "display_name must default to the map key and honour an explicit value."
  }

  assert {
    condition     = oci_logging_log.logs["lb-access"].configuration[0].source[0].category == "access" && oci_logging_log.logs["lb-error"].configuration[0].source[0].category == "error"
    error_message = "Each SERVICE log must carry its own source configuration."
  }

  assert {
    condition     = oci_logging_log.logs["lb-error"].retention_duration == 90 && oci_logging_log.logs["lb-access"].retention_duration == 30
    error_message = "retention_duration must be passed through and default to 30."
  }

  assert {
    condition     = oci_logging_log.logs["app"].log_type == "CUSTOM" && oci_logging_log.logs["app"].is_enabled == true && length(oci_logging_log.logs["app"].configuration) == 0
    error_message = "An empty logs entry must default to an enabled CUSTOM log without a source."
  }

  assert {
    condition     = length(output.log_ids) == 3 && output.log_ids["lb-access"] == oci_logging_log.logs["lb-access"].id
    error_message = "log_ids must map every var.logs key to its log OCID."
  }

  assert {
    condition     = output.log_id == null
    error_message = "log_id must stay null when var.log is not set."
  }
}

run "log_and_logs_combine" {
  variables {
    log = {
      display_name = "app-custom-log"
    }
    logs = {
      audit = {}
    }
  }

  assert {
    condition     = length(oci_logging_log.this) == 1 && length(oci_logging_log.logs) == 1
    error_message = "var.log and var.logs must be usable together."
  }

  assert {
    condition     = output.log_id == oci_logging_log.this[0].id && output.log_ids["audit"] == oci_logging_log.logs["audit"].id
    error_message = "log_id and log_ids must expose their own logs."
  }
}

run "duplicate_name_across_log_and_logs_is_rejected" {
  command = plan

  variables {
    log = {
      display_name = "app"
    }
    logs = {
      app = {}
    }
  }

  expect_failures = [oci_logging_log_group.this]
}

run "duplicate_name_within_logs_is_rejected" {
  command = plan

  variables {
    logs = {
      one = { display_name = "same" }
      two = { display_name = "same" }
    }
  }

  expect_failures = [var.logs]
}

run "logs_service_entry_without_source_is_rejected" {
  command = plan

  variables {
    logs = {
      flow = { log_type = "SERVICE" }
    }
  }

  expect_failures = [var.logs]
}

run "logs_custom_entry_with_source_is_rejected" {
  command = plan

  variables {
    logs = {
      app = {
        source = {
          service  = "flowlogs"
          resource = "ocid1.subnet.oc1..aaaaaaaaexample"
          category = "all"
        }
      }
    }
  }

  expect_failures = [var.logs]
}

run "logs_retention_outside_increments_is_rejected" {
  command = plan

  variables {
    logs = {
      app = { retention_duration = 45 }
    }
  }

  expect_failures = [var.logs]
}

run "logs_unknown_log_type_is_rejected" {
  command = plan

  variables {
    logs = {
      app = { log_type = "NotAValidValue" }
    }
  }

  expect_failures = [var.logs]
}

run "logs_unknown_source_type_is_rejected" {
  command = plan

  variables {
    logs = {
      flow = {
        log_type = "SERVICE"
        source = {
          service     = "flowlogs"
          resource    = "ocid1.subnet.oc1..aaaaaaaaexample"
          category    = "all"
          source_type = "SOMETHINGELSE"
        }
      }
    }
  }

  expect_failures = [var.logs]
}
