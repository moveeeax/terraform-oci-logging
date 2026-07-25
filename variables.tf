variable "compartment_id" {
  description = "OCID of the compartment in which to create the log group."
  type        = string
}

variable "display_name" {
  description = "Human-readable name for the log group."
  type        = string
}

variable "description" {
  description = "Description of the log group."
  type        = string
  default     = null
}

variable "log" {
  description = <<-EOT
    Optional log to create inside the group. Null creates only the group, which
    collects nothing on its own — a log group is just an IAM/organisational
    container.

    `log_type = "SERVICE"` additionally requires `source`, which names the OCI
    service and resource whose events are routed into the log. A service log
    without a source is created successfully but never receives a single event.

    `log_type = "CUSTOM"` must not set `source`: custom logs are written by the
    Unified Monitoring Agent or the PutLogs API, not by an OCI service.
  EOT
  type = object({
    display_name       = string
    log_type           = optional(string, "CUSTOM")
    retention_duration = optional(number, 30)
    is_enabled         = optional(bool, true)
    source = optional(object({
      service     = string
      resource    = string
      category    = string
      source_type = optional(string, "OCISERVICE")
      parameters  = optional(map(string))
    }))
  })
  default = null

  validation {
    condition     = var.log == null ? true : contains(["CUSTOM", "SERVICE"], var.log.log_type)
    error_message = "log.log_type must be CUSTOM or SERVICE."
  }

  validation {
    condition     = var.log == null ? true : contains([30, 60, 90, 120, 150, 180], var.log.retention_duration)
    error_message = "log.retention_duration must be one of 30, 60, 90, 120, 150, 180. OCI accepts retention only in 30-day increments up to 180 days and rejects anything else at apply time."
  }

  validation {
    condition     = var.log == null ? true : (var.log.log_type != "SERVICE" || var.log.source != null)
    error_message = "log.source is required when log.log_type is SERVICE. A service log created without a source configuration is provisioned successfully but never receives any events."
  }

  validation {
    condition     = var.log == null ? true : (var.log.log_type != "CUSTOM" || var.log.source == null)
    error_message = "log.source must not be set when log.log_type is CUSTOM. Custom logs are written by the Unified Monitoring Agent or the PutLogs API, not by an OCI service."
  }

  validation {
    condition     = var.log == null ? true : (var.log.source == null || var.log.source.source_type == "OCISERVICE")
    error_message = "log.source.source_type must be OCISERVICE, the only source type OCI Logging supports."
  }
}

variable "freeform_tags" {
  description = "Free-form tags applied to the log group and log."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "Defined tags applied to the log group and log, keyed as \"namespace.key\"."
  type        = map(string)
  default     = {}
}
