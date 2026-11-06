resource "oci_logging_log_group" "this" {
  compartment_id = var.compartment_id
  display_name   = var.display_name
  description    = var.description

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  lifecycle {
    precondition {
      condition     = length(local.all_log_names) == length(distinct(local.all_log_names))
      error_message = "Log display names must be unique within the log group, across log and logs (a logs entry without display_name uses its map key)."
    }
  }
}

locals {
  # display_name of every log the module creates in the group; OCI requires
  # them to be unique within the group.
  all_log_names = concat(
    var.log == null ? [] : [var.log.display_name],
    [for k, l in var.logs : coalesce(l.display_name, k)],
  )
}

# The single log from var.log. Kept at its original address so existing state
# is untouched; new code can use var.logs instead.
resource "oci_logging_log" "this" {
  count = var.log != null ? 1 : 0

  log_group_id       = oci_logging_log_group.this.id
  display_name       = var.log.display_name
  log_type           = var.log.log_type
  retention_duration = var.log.retention_duration
  is_enabled         = var.log.is_enabled

  # Only SERVICE logs carry a configuration; it is what actually wires an OCI
  # service's events into the log. Without it the log is created and stays
  # permanently empty. var.log validation guarantees source is set exactly when
  # log_type is SERVICE.
  dynamic "configuration" {
    for_each = var.log.source == null ? [] : [var.log.source]

    content {
      compartment_id = var.compartment_id

      source {
        service     = configuration.value.service
        resource    = configuration.value.resource
        category    = configuration.value.category
        source_type = configuration.value.source_type
        parameters  = configuration.value.parameters
      }
    }
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

# Several logs in the same group, one per var.logs entry.
resource "oci_logging_log" "logs" {
  for_each = var.logs

  log_group_id       = oci_logging_log_group.this.id
  display_name       = coalesce(each.value.display_name, each.key)
  log_type           = each.value.log_type
  retention_duration = each.value.retention_duration
  is_enabled         = each.value.is_enabled

  # Same wiring as the single log above: only SERVICE logs carry a source.
  dynamic "configuration" {
    for_each = each.value.source == null ? [] : [each.value.source]

    content {
      compartment_id = var.compartment_id

      source {
        service     = configuration.value.service
        resource    = configuration.value.resource
        category    = configuration.value.category
        source_type = configuration.value.source_type
        parameters  = configuration.value.parameters
      }
    }
  }

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}
