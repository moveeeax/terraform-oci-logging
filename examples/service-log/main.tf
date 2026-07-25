provider "oci" {}

# A SERVICE log needs a source: the OCI service, the resource emitting the
# events, and the log category. Without it OCI creates the log and nothing ever
# writes to it.
module "logging" {
  source = "../.."

  compartment_id = var.compartment_id
  display_name   = "example-service-log-group"
  description    = "VCN flow logs"

  log = {
    display_name       = "subnet-flow-logs"
    log_type           = "SERVICE"
    retention_duration = 90

    source = {
      service  = "flowlogs"
      resource = var.subnet_id
      category = "all"
    }
  }

  freeform_tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

variable "compartment_id" {
  description = "Compartment OCID to deploy the example log group into."
  type        = string
}

variable "subnet_id" {
  description = "OCID of the subnet whose flow logs are captured."
  type        = string
}

output "log_group_id" {
  value = module.logging.log_group_id
}

output "log_id" {
  value = module.logging.log_id
}
