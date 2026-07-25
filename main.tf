resource "oci_logging_log_group" "this" {
  compartment_id = var.compartment_id
  display_name   = var.display_name
  description    = var.description

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags
}

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
