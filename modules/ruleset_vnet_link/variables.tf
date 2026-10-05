variable "dns_forwarding_ruleset_id" {
  type        = string
  description = "The ID of the DNS forwarding ruleset to link to the virtual networks."

  validation {
    # TFNFR38 (Severity-MUST): a LITERAL type through `parse_resource_id`, never a regex.
    condition = (
      can(provider::azapi::parse_resource_id("Microsoft.Network/dnsForwardingRulesets", var.dns_forwarding_ruleset_id)) &&
      try(provider::azapi::parse_resource_id("Microsoft.Network/dnsForwardingRulesets", var.dns_forwarding_ruleset_id).resource_group_name, "") != ""
    )
    error_message = "`dns_forwarding_ruleset_id` must be a valid `Microsoft.Network/dnsForwardingRulesets` resource ID, for example `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/dnsForwardingRulesets/ruleset`."
  }
}

variable "virtual_networks" {
  type = map(object({
    vnet_id = string
  metadata = optional(map(string), null) }))
  description = <<DESCRIPTION
A map virtual network links to create.
  - `vnet_id` - (Required) The ID of the virtual network to link to.
  - `metadata` - (Optional) A map of metadata to associate with the virtual network link.
DESCRIPTION

  validation {
    # TFNFR38 (Severity-MUST): a LITERAL type through `parse_resource_id`, never a regex.
    condition = alltrue([
      for vnet in var.virtual_networks :
      can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", vnet.vnet_id)) &&
      try(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", vnet.vnet_id).resource_group_name, "") != ""
    ])
    error_message = "Every `virtual_networks[*].vnet_id` must be a valid `Microsoft.Network/virtualNetworks` resource ID."
  }
}

variable "ignore_body_changes" {
  type = object({
    network_dns_forwarding_rulesets_virtual_network_links = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Body property paths whose changes the `azapi` provider ignores after creation, letting an out-of-band controller own those properties without producing perpetual `terraform plan` drift.

- `network_dns_forwarding_rulesets_virtual_network_links` - (Optional) Ignored body paths for the virtual network links, in dot notation relative to the request body, for example `["properties.metadata"]`. Default `[]`.

While a path is ignored, configuration changes at that path are no longer sent to Azure. The value is write-only provider state, so a change only takes effect after an `apply`, and supplying a non-empty list requires Terraform 1.11 or later. An empty list is collapsed to `null` before it reaches the provider.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for path in var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links : length(trimspace(path)) > 0])
    error_message = "Every `ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links` entry must be a non-empty body path in dot notation, for example \"properties.metadata\"."
  }
}

variable "resource_types" {
  type = object({
    network_dns_forwarding_rulesets_virtual_network_links = optional(string, "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2025-05-01")
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) The Azure resource type and API version used for each resource created by this module.

- `network_dns_forwarding_rulesets_virtual_network_links` - (Optional) The type and API version of the virtual network links. Default `Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2025-05-01`.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for type in values(var.resource_types) : can(regex("^[^/@]+/[^@]+@[0-9]{4}-[0-9]{2}-[0-9]{2}(-preview)?$", type))
    ])
    error_message = "Every `resource_types` entry must be of the form `Namespace/type@yyyy-mm-dd`, for example `Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2025-05-01`."
  }
}

variable "retry" {
  type = object({
    error_message_regex = optional(list(string), [
      "AnotherOperationInProgress",
      "ReferencedResourceNotProvisioned",
      "CannotDeleteResource",
    ])
    interval_seconds     = optional(number, null)
    max_interval_seconds = optional(number, null)
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) The retry configuration applied to every `azapi_resource` created by this module.

- `error_message_regex` - (Optional) A list of regular expressions matched against the error message. The request is retried when any of them matches. The AzAPI provider requires this attribute, so it cannot be `null`; pass `[]` to disable retries. The default covers `AnotherOperationInProgress` (a concurrent write against the same forwarding ruleset or virtual network), `ReferencedResourceNotProvisioned` (the virtual network is still provisioning) and `CannotDeleteResource` (on teardown, ARM still reports a nested resource as present after its `DELETE` has already completed).
- `interval_seconds` - (Optional) The base number of seconds to wait between retries. Defaults to the AzAPI provider default (`10`).
- `max_interval_seconds` - (Optional) The maximum number of seconds to wait between retries. Defaults to the AzAPI provider default (`180`).
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Timeouts for the resource operations. Each value must be a string parsable as a Go duration, for example `"30s"`, `"5m"` or `"1h30m"`.

Any attribute left unset falls back to the timeout default of `azurerm_private_dns_resolver_virtual_network_link`: create 30m, read 5m, update 30m, delete 30m. The fallbacks live in `local.timeouts` in `locals.tf`.

Set the whole object to `null` to omit the `timeouts` block entirely and use the AzAPI provider defaults.

- `create` - (Optional) Timeout for create operations.
- `read` - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
