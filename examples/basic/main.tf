provider "oci" {}

module "logging" {
  source = "../.."

  compartment_id = var.compartment_id
  display_name   = "example-log-group"
  description    = "Application log group"

  log = {
    display_name = "app-custom-log"
    log_type     = "CUSTOM"
  }

  freeform_tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

# Several logs in one group: one log per map entry, display_name defaults to
# the key.
module "app_logs" {
  source = "../.."

  compartment_id = var.compartment_id
  display_name   = "example-app-log-group"

  logs = {
    app-stdout = {}
    app-audit = {
      retention_duration = 180
    }
  }
}

variable "compartment_id" {
  description = "Compartment OCID to deploy the example log group into."
  type        = string
}

output "log_group_id" {
  value = module.logging.log_group_id
}

output "app_log_ids" {
  value = module.app_logs.log_ids
}
