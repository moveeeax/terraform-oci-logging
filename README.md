# terraform-oci-logging

Terraform module that manages an [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/)
Logging log group and, optionally, one or several logs inside it. Log groups are containers that
organise logs and control their IAM policies.

## Usage

```hcl
module "logging" {
  source = "github.com/moveeeax/terraform-oci-logging?ref=v1.0.0"

  compartment_id = var.compartment_id
  display_name   = "prod-log-group"
  description    = "Production application logs"

  log = {
    display_name       = "app-custom-log"
    log_type           = "CUSTOM"
    retention_duration = 90
  }

  freeform_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

### Service logs

A `SERVICE` log must say which OCI service and resource it collects from. That is
what `log.source` is for — OCI will happily create a service log without one, and
it will then sit there permanently empty, so the module refuses the combination at
plan time.

```hcl
module "flow_logs" {
  source = "github.com/moveeeax/terraform-oci-logging?ref=v1.0.0"

  compartment_id = var.compartment_id
  display_name   = "network-log-group"

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
}
```

Conversely a `CUSTOM` log must not set `log.source`: custom logs are written by
the Unified Monitoring Agent or the `PutLogs` API, not by an OCI service.

### Several logs per group

`logs` is a map of logs to create in the same group. Each entry takes the same
fields as `log`, and `display_name` defaults to the map key. The `log_ids` output
maps the same keys to log OCIDs.

```hcl
module "lb_logs" {
  source = "github.com/moveeeax/terraform-oci-logging?ref=v1.2.0"

  compartment_id = var.compartment_id
  display_name   = "lb-log-group"

  logs = {
    lb-access = {
      log_type = "SERVICE"
      source   = { service = "loadbalancer", resource = var.lb_id, category = "access" }
    }
    lb-error = {
      log_type           = "SERVICE"
      retention_duration = 90
      source             = { service = "loadbalancer", resource = var.lb_id, category = "error" }
    }
  }
}
```

Flow logs for every subnet follow the same shape, e.g.
`logs = { for name, id in var.subnet_ids : name => { log_type = "SERVICE", source = { service = "flowlogs", resource = id, category = "all" } } }`.

`log` still works and can be combined with `logs`. Log display names must be
unique within the group (an OCI rule), so the plan fails when two logs, from `log`
or `logs`, resolve to the same name.

Runnable examples live in [`examples/basic`](examples/basic) and
[`examples/service-log`](examples/service-log).

## Notes

- `retention_duration` accepts only `30`, `60`, `90`, `120`, `150` or `180`. OCI
  takes retention in 30-day increments up to 180 days and rejects anything else
  with an API error at apply time, so the module checks it at plan time.
- Logs default to `is_enabled = true`. Setting it to `false` keeps the log object
  but stops collection entirely.
- Leaving both `log` and `logs` unset creates the log group alone. A log group collects nothing by
  itself — it is an IAM and organisational container — so this is only useful when
  the logs inside it are managed elsewhere.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| oci       | >= 5.0   |

## Inputs

| Name             | Description                                                       | Type          | Default | Required |
|------------------|-------------------------------------------------------------------|---------------|---------|:--------:|
| `compartment_id` | OCID of the compartment in which to create the log group.         | `string`      | n/a     |   yes    |
| `display_name`   | Human-readable name for the log group.                            | `string`      | n/a     |   yes    |
| `description`    | Description of the log group.                                     | `string`      | `null`  |    no    |
| `log`            | Optional single log to create inside the group (see below).       | `object(...)` | `null`  |    no    |
| `logs`           | Logs to create inside the group, keyed by name; each entry like `log`, `display_name` optional (defaults to the key). | `map(object(...))` | `{}` | no |
| `freeform_tags`  | Free-form tags applied to the log group and its logs.             | `map(string)` | `{}`    |    no    |
| `defined_tags`   | Defined tags applied to the group and log, keyed `namespace.key`. | `map(string)` | `{}`    |    no    |

### `log` object (and each `logs` entry)

In `logs` entries `display_name` is optional and defaults to the map key.

| Attribute            | Description                                                     | Type          | Default     | Required |
|----------------------|-----------------------------------------------------------------|---------------|-------------|:--------:|
| `display_name`       | Human-readable name for the log.                                | `string`      | n/a         |   yes    |
| `log_type`           | `CUSTOM` or `SERVICE`.                                          | `string`      | `"CUSTOM"`  |    no    |
| `retention_duration` | Retention in days: `30`, `60`, `90`, `120`, `150` or `180`.     | `number`      | `30`        |    no    |
| `is_enabled`         | Whether the log collects events.                                | `bool`        | `true`      |    no    |
| `source`             | Service source. Required for `SERVICE`, forbidden for `CUSTOM`. | `object(...)` | `null`      |    no    |

### `log.source` object

| Attribute     | Description                                          | Type          | Default         | Required |
|---------------|------------------------------------------------------|---------------|-----------------|:--------:|
| `service`     | OCI service generating the log, e.g. `flowlogs`.     | `string`      | n/a             |   yes    |
| `resource`    | OCID of the resource emitting the log.               | `string`      | n/a             |   yes    |
| `category`    | Log category for that service, e.g. `all`.           | `string`      | n/a             |   yes    |
| `source_type` | Only `OCISERVICE` is supported.                      | `string`      | `"OCISERVICE"`  |    no    |
| `parameters`  | Extra parameters required by some service categories.| `map(string)` | `null`          |    no    |

## Outputs

| Name                     | Description                                    |
|--------------------------|------------------------------------------------|
| `log_group_id`           | OCID of the log group.                         |
| `log_group_display_name` | Display name of the log group.                 |
| `log_id`                 | OCID of the log from `log`, or `null`.         |
| `log_ids`                | Map of `logs` keys to log OCIDs.               |
| `state`                  | Lifecycle state of the log group.              |

## Testing

```sh
terraform init -backend=false
terraform test
```

The suite in [`tests/`](tests) uses `mock_provider`, so it needs no OCI
credentials and no network. Running it requires Terraform or OpenTofu >= 1.7; the
module itself still only requires >= 1.5.

## License

[MIT](LICENSE)
