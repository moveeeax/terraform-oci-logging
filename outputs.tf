output "log_group_id" {
  description = "OCID of the log group."
  value       = oci_logging_log_group.this.id
}

output "log_group_display_name" {
  description = "Display name of the log group."
  value       = oci_logging_log_group.this.display_name
}

output "log_id" {
  description = "OCID of the log created from var.log, or null when var.log is not set. Logs from var.logs are in log_ids."
  value       = try(oci_logging_log.this[0].id, null)
}

output "log_ids" {
  description = "OCIDs of the logs created from var.logs, keyed like var.logs. The log from var.log is in log_id."
  value       = { for k, l in oci_logging_log.logs : k => l.id }
}

output "state" {
  description = "Lifecycle state of the log group."
  value       = oci_logging_log_group.this.state
}
