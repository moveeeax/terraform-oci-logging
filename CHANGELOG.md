# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `logs` input: a map of logs to create in the same log group (for example flow
  logs for every subnet, or load balancer access and error logs). Each entry
  takes the fields of `log`; `display_name` defaults to the map key. Entries are
  validated like `log` (log type, source rules, 30-day retention increments).
- `log_ids` output: map of `logs` keys to log OCIDs.
- The plan fails when two logs in the group resolve to the same display name,
  which OCI rejects.

### Changed

- `log` stays the default path and keeps its resource address
  (`oci_logging_log.this[0]`) and `log_id` output; it can be combined with `logs`.

[Unreleased]: https://github.com/moveeeax/terraform-oci-logging/compare/v1.1.0...HEAD
