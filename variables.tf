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

variable "logs" {
  description = <<-EOT
    Logs to create inside the group, keyed by a stable name. Each entry takes the
    same fields as `log`; display_name defaults to the map key. Use this for
    several logs in one group, for example flow logs for every subnet or access
    and error logs of a load balancer. Can be combined with `log`; display names
    must be unique within the group.

    The same rules as for `log` apply: SERVICE logs require `source`, CUSTOM logs
    must not set it, and retention_duration is 30, 60, 90, 120, 150 or 180.
  EOT
  type = map(object({
    display_name       = optional(string)
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
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for l in values(var.logs) : contains(["CUSTOM", "SERVICE"], l.log_type)])
    error_message = "Every logs entry must have log_type CUSTOM or SERVICE."
  }

  validation {
    condition     = alltrue([for l in values(var.logs) : contains([30, 60, 90, 120, 150, 180], l.retention_duration)])
    error_message = "Every logs entry must have retention_duration 30, 60, 90, 120, 150 or 180. OCI accepts retention only in 30-day increments up to 180 days and rejects anything else at apply time."
  }

  validation {
    condition     = alltrue([for l in values(var.logs) : l.log_type != "SERVICE" || l.source != null])
    error_message = "source is required for every logs entry with log_type SERVICE. A service log created without a source configuration is provisioned successfully but never receives any events."
  }

  validation {
    condition     = alltrue([for l in values(var.logs) : l.log_type != "CUSTOM" || l.source == null])
    error_message = "source must not be set on a logs entry with log_type CUSTOM. Custom logs are written by the Unified Monitoring Agent or the PutLogs API, not by an OCI service."
  }

  validation {
    condition     = alltrue([for l in values(var.logs) : l.source == null || try(l.source.source_type == "OCISERVICE", false)])
    error_message = "source.source_type must be OCISERVICE, the only source type OCI Logging supports."
  }

  validation {
    condition     = alltrue([for k, l in var.logs : try(trimspace(coalesce(l.display_name, k)) != "", false)])
    error_message = "Every logs entry needs a non-empty display_name (or a non-empty map key)."
  }

  validation {
    condition     = length(distinct([for k, l in var.logs : coalesce(l.display_name, k)])) == length(var.logs)
    error_message = "Log display names must be unique within the log group; two logs entries resolve to the same display_name."
  }
}

variable "freeform_tags" {
  description = "Free-form tags applied to the log group and its logs."
  type        = map(string)
  default     = {}
}

variable "defined_tags" {
  description = "Defined tags applied to the log group and its logs, keyed as \"namespace.key\"."
  type        = map(string)
  default     = {}
}
