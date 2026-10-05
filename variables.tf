variable "location" {
  type        = string
  description = "Azure region where the resource should be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the dns resolver."

  validation {
    condition     = can(regex("^[^#]+$", var.name))
    error_message = "The name must be at least 1 characters long."
  }
}

# This is required for most resource modules
variable "resource_group_name" {
  type        = string
  description = "The resource group where the resources will be deployed."
}

variable "virtual_network_resource_id" {
  type        = string
  description = <<DESCRIPTION
The ID of the virtual network to deploy the inbound and outbound endpoints into. The vnet should have appropriate subnets for the endpoints.
For more information on how to configure subnets for inbound and outbounbd endpoints, see the modules readme.
DESCRIPTION

  validation {
    # TFNFR38 (Severity-MUST): validate a resource ID with a LITERAL type through
    # `provider::azapi::parse_resource_id`, never with a hand-rolled regex.
    condition = (
      can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", var.virtual_network_resource_id)) &&
      try(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", var.virtual_network_resource_id).resource_group_name, "") != ""
    )
    error_message = "`virtual_network_resource_id` must be a valid `Microsoft.Network/virtualNetworks` resource ID, for example `/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet`."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "ignore_body_changes" {
  type = object({
    network_dns_forwarding_rulesets                       = optional(list(string), [])
    network_dns_forwarding_rulesets_forwarding_rules      = optional(list(string), [])
    network_dns_forwarding_rulesets_virtual_network_links = optional(list(string), [])
    network_dns_resolvers                                 = optional(list(string), [])
    network_dns_resolvers_inbound_endpoints               = optional(list(string), [])
    network_dns_resolvers_outbound_endpoints              = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) Body property paths whose changes the `azapi` provider ignores after creation, letting an out-of-band controller own those properties without producing perpetual `terraform plan` drift.

Paths are in dot notation relative to the request body, for example `["properties.dnsResolverOutboundEndpoints"]`.

- `network_dns_forwarding_rulesets` - (Optional) Ignored body paths for the DNS forwarding rulesets. Default `[]`.
- `network_dns_forwarding_rulesets_forwarding_rules` - (Optional) Ignored body paths for the forwarding rules. Default `[]`.
- `network_dns_forwarding_rulesets_virtual_network_links` - (Optional) Ignored body paths for both the default and the additional virtual network links. Default `[]`.
- `network_dns_resolvers` - (Optional) Ignored body paths for the DNS resolver. Default `[]`.
- `network_dns_resolvers_inbound_endpoints` - (Optional) Ignored body paths for the inbound endpoints. Default `[]`.
- `network_dns_resolvers_outbound_endpoints` - (Optional) Ignored body paths for the outbound endpoints. Default `[]`.

While a path is ignored, configuration changes at that path are no longer sent to Azure. The value is write-only provider state, so a change only takes effect after an `apply`, and supplying a non-empty list requires Terraform 1.11 or later. Empty lists are collapsed to `null` before they reach the provider.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue(flatten([
      for paths in values(var.ignore_body_changes) : [
        for path in paths : length(trimspace(path)) > 0
      ]
    ]))
    error_message = "Every `ignore_body_changes` entry must be a non-empty body path in dot notation, for example \"properties.dnsResolverOutboundEndpoints\"."
  }
}

variable "inbound_endpoints" {
  type = map(object({
    name                         = optional(string)
    subnet_name                  = string
    private_ip_allocation_method = optional(string, "Dynamic")
    private_ip_address           = optional(string, null)
    tags                         = optional(map(string), null)
    merge_with_module_tags       = optional(bool, true)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of inbound endpoints to create for this DNS resolver.

- `name` - (Optional) The name of the inbound endpoint.
- `subnet_name` - (Required) The name of the subnet within the virtual network specified by `virtual_network_resource_id` where the inbound endpoint will be deployed.
- `private_ip_allocation_method` - (Optional) The allocation method for the private IP address. Possible values are `Dynamic` (default) or `Static`.
- `private_ip_address` - (Optional) The static private IP address to assign if `private_ip_allocation_method` is set to `Static`.
- `tags` - (Optional) A map of tags to assign to the inbound endpoint.
- `merge_with_module_tags` - (Optional) Whether to merge the module tags with the inbound endpoint tags. Defaults to true.

Multiple inbound endpoints can be created by providing multiple entries in the map.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for endpoint in var.inbound_endpoints : contains(["Dynamic", "Static"], endpoint.private_ip_allocation_method)])
    error_message = "`inbound_endpoints[*].private_ip_allocation_method` must be either `Dynamic` or `Static`."
  }
  validation {
    # Reproduces the check AzureRM performed in `expandIPConfigurationModel`
    # (inbound_endpoint_resource.go L296-303), which failed at apply time. Failing at plan
    # time is strictly better, and AzAPI would otherwise send the request straight to ARM.
    condition     = alltrue([for endpoint in var.inbound_endpoints : !(endpoint.private_ip_allocation_method == "Dynamic" && endpoint.private_ip_address != null)])
    error_message = "`inbound_endpoints[*].private_ip_address` must not be set when `private_ip_allocation_method` is `Dynamic`."
  }
  validation {
    condition     = alltrue([for endpoint in var.inbound_endpoints : !(endpoint.private_ip_allocation_method == "Static" && endpoint.private_ip_address == null)])
    error_message = "`inbound_endpoints[*].private_ip_address` is required when `private_ip_allocation_method` is `Static`."
  }
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
  Controls the Resource Lock configuration for this resource. The following properties can be specified:
  
  - `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
  - `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
  DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

# The outbound_endpoints variable is an object that allows creating outbound endpoints and related resources such as forwarding rulesets, rules and virtual network links
# This is done in a hierarchial manner to best describe the relationship between the resources
# The provider objects are broken down into lists in the locals.tf file to allow creation of the resources
variable "outbound_endpoints" {
  type = map(object({
    name                   = optional(string)
    tags                   = optional(map(string), null)
    merge_with_module_tags = optional(bool, true)
    subnet_name            = string
    forwarding_ruleset = optional(map(object({
      name                                                = optional(string)
      link_with_outbound_endpoint_virtual_network         = optional(bool, true)
      metadata_for_outbound_endpoint_virtual_network_link = optional(map(string), null)
      tags                                                = optional(map(string), null)
      merge_with_module_tags                              = optional(bool, true)
      additional_outbound_endpoint_link = optional(object({
        outbound_endpoint_key = optional(string)
      }), null)
      additional_virtual_network_links = optional(map(object({
        name     = optional(string)
        vnet_id  = string
        metadata = optional(map(string), null)
      })), {})
      rules = optional(map(object({
        name                     = optional(string)
        domain_name              = string
        destination_ip_addresses = map(string)
        enabled                  = optional(bool, true)
        metadata                 = optional(map(string), null)
      })))
    })))
  }))
  default     = {}
  description = <<DESCRIPTION
A map of outbound endpoints to create for this DNS resolver.

- `name` - (Optional) The name of the outbound endpoint.
- `tags` - (Optional) A map of tags to assign to the outbound endpoint.
- `merge_with_module_tags` - (Optional) Whether to merge the module tags with the outbound endpoint tags. Defaults to true.
- `subnet_name` - (Required) The name of the subnet within the virtual network specified by `virtual_network_resource_id` where the outbound endpoint will be deployed.
- `forwarding_ruleset` - (Optional) A map of forwarding rulesets to create for the outbound endpoint.
  - `name` - (Optional) The name of the forwarding ruleset.
  - `link_with_outbound_endpoint_virtual_network` - (Optional) Whether to link the forwarding ruleset with the outbound endpoint's virtual network. Defaults to true.
  - `metadata_for_outbound_endpoint_virtual_network_link` - (Optional) A map of metadata to associate with the virtual network link.
  - `tags` - (Optional) A map of tags to assign to the forwarding ruleset.
  - `merge_with_module_tags` - (Optional) Whether to merge the module tags with the forwarding ruleset tags. Defaults to true.
  - `additional_outbound_endpoint_link` - (Optional) An object to specify an additional outbound endpoint link.
    - `outbound_endpoint_key` - (Optional) The key of another outbound endpoint created in this module. See examples.
  - `additional_virtual_network_links` - (Optional) A map of additional virtual network links to create.
    - `name` - (Optional) The name of the additional virtual network link.
    - `vnet_id` - (Required) The ID of the virtual network to link to.
    - `metadata` - (Optional) A map of metadata to associate with the virtual network link.
  - `rules` - (Optional) A map of forwarding rules to create for the forwarding ruleset.
    - `name` - (Optional) The name of the forwarding rule.
    - `domain_name` - (Required) The domain name to forward.
    - `destination_ip_addresses` - (Required) A map where the key is the IP address and the value is the port.
    - `enabled` - (Optional) Whether the forwarding rule is enabled. Defaults to true.
    - `metadata` - (Optional) A map of metadata to associate with the forwarding rule.

Multiple outbound endpoints can be created by providing multiple entries in the map.
DESCRIPTION
  nullable    = false

  validation {
    # TFNFR38 (Severity-MUST): a LITERAL type through `parse_resource_id`, never a regex.
    condition = alltrue(flatten([
      for endpoint in var.outbound_endpoints : [
        for ruleset in coalesce(endpoint.forwarding_ruleset, {}) : [
          for link in ruleset.additional_virtual_network_links :
          can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", link.vnet_id)) &&
          try(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", link.vnet_id).resource_group_name, "") != ""
        ]
      ]
    ]))
    error_message = "Every `outbound_endpoints[*].forwarding_ruleset[*].additional_virtual_network_links[*].vnet_id` must be a valid `Microsoft.Network/virtualNetworks` resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for endpoint in var.outbound_endpoints : [
        for ruleset in coalesce(endpoint.forwarding_ruleset, {}) : [
          for rule in coalesce(ruleset.rules, {}) : [
            for port in values(rule.destination_ip_addresses) : can(tonumber(port))
          ]
        ]
      ]
    ]))
    error_message = "Every value in `outbound_endpoints[*].forwarding_ruleset[*].rules[*].destination_ip_addresses` must be a port number, for example `\"53\"`. The map key is the destination IP address and the value is the port."
  }
}

variable "resource_types" {
  type = object({
    network_dns_forwarding_rulesets                       = optional(string, "Microsoft.Network/dnsForwardingRulesets@2025-05-01")
    network_dns_forwarding_rulesets_forwarding_rules      = optional(string, "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2025-05-01")
    network_dns_forwarding_rulesets_virtual_network_links = optional(string, "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2025-05-01")
    network_dns_resolvers                                 = optional(string, "Microsoft.Network/dnsResolvers@2025-05-01")
    network_dns_resolvers_inbound_endpoints               = optional(string, "Microsoft.Network/dnsResolvers/inboundEndpoints@2025-05-01")
    network_dns_resolvers_outbound_endpoints              = optional(string, "Microsoft.Network/dnsResolvers/outboundEndpoints@2025-05-01")
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) The Azure resource type and API version used for each resource created by this module. Each default is the latest GA API version for that type.

- `network_dns_forwarding_rulesets` - (Optional) The type and API version of the DNS forwarding rulesets. Default `Microsoft.Network/dnsForwardingRulesets@2025-05-01`.
- `network_dns_forwarding_rulesets_forwarding_rules` - (Optional) The type and API version of the forwarding rules. Default `Microsoft.Network/dnsForwardingRulesets/forwardingRules@2025-05-01`.
- `network_dns_forwarding_rulesets_virtual_network_links` - (Optional) The type and API version of the virtual network links. Default `Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2025-05-01`.
- `network_dns_resolvers` - (Optional) The type and API version of the DNS resolver. Default `Microsoft.Network/dnsResolvers@2025-05-01`.
- `network_dns_resolvers_inbound_endpoints` - (Optional) The type and API version of the inbound endpoints. Default `Microsoft.Network/dnsResolvers/inboundEndpoints@2025-05-01`.
- `network_dns_resolvers_outbound_endpoints` - (Optional) The type and API version of the outbound endpoints. Default `Microsoft.Network/dnsResolvers/outboundEndpoints@2025-05-01`.

The lock and role assignment types are owned by the `Azure/avm-utl-interfaces/azure` module and are not configurable here.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for type in values(var.resource_types) : can(regex("^[^/@]+/[^@]+@[0-9]{4}-[0-9]{2}-[0-9]{2}(-preview)?$", type))
    ])
    error_message = "Every `resource_types` entry must be of the form `Namespace/type@yyyy-mm-dd`, for example `Microsoft.Network/dnsResolvers@2025-05-01`."
  }
}

variable "retry" {
  type = object({
    error_message_regex = optional(list(string), [
      "AnotherOperationInProgress",
      "ReferencedResourceNotProvisioned",
      "CannotDeleteResource",
      "PrincipalNotFound",
      "ScopeLocked",
    ])
    interval_seconds     = optional(number, null)
    max_interval_seconds = optional(number, null)
  })
  default     = {}
  description = <<DESCRIPTION
(Optional) The retry configuration applied to every `azapi_resource` created by this module.

- `error_message_regex` - (Optional) A list of regular expressions matched against the error message. The request is retried when any of them matches. The AzAPI provider requires this attribute, so it cannot be `null`; pass `[]` to disable retries.
- `interval_seconds` - (Optional) The base number of seconds to wait between retries. Defaults to the AzAPI provider default (`10`).
- `max_interval_seconds` - (Optional) The maximum number of seconds to wait between retries. Defaults to the AzAPI provider default (`180`).

The default list covers the transient failures this module's resources actually hit:

- `AnotherOperationInProgress` - a concurrent write against the same virtual network or subnet.
- `ReferencedResourceNotProvisioned` - the subnet or virtual network is still provisioning.
- `CannotDeleteResource` - on teardown, ARM still reports a nested resource (an inbound or outbound endpoint, or a forwarding rule) as present after its `DELETE` has already completed. Matches the default of the AVM AzAPI reference module `avm-res-network-privatednszone`.
- `PrincipalNotFound` - the role assignment principal has not finished propagating through Entra ID. This replaces the `skip_service_principal_aad_check` argument, which has no ARM equivalent.
- `ScopeLocked` - a management lock is still being removed from the scope.
DESCRIPTION
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
  A map of role assignments to create on the <RESOURCE>. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
  
  - `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
  - `principal_id` - The ID of the principal to assign the role to.
  - `description` - (Optional) The description of the role assignment.
  - `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
  - `condition` - (Optional) The condition which will be used to scope the role assignment.
  - `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
  - `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
  - `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.
  
  > Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
  DESCRIPTION
  nullable    = false
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
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

Any attribute left unset falls back to the timeout default of the `azurerm` resource this module replaced. Every replaced resource -- the six `azurerm_private_dns_resolver*` resources plus `azurerm_management_lock` and `azurerm_role_assignment` -- shared the same defaults: create 30m, read 5m, update 30m, delete 30m. The fallbacks live in `local.timeouts` in `locals.tf`.

Set the whole object to `null` to omit the `timeouts` block entirely and use the AzAPI provider defaults.

- `create` - (Optional) Timeout for create operations.
- `read` - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
