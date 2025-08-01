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
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
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
