variable "location" {
  type        = string
  description = "Azure region where the resource should be deployed."
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
  }))
  default     = {}
  description = <<DESCRIPTION
A map of inbound endpoints to create on this resource. 
Multiple endpoints can be created by providing multiple entries in the map.
For each endpoint, the `subnet_name` is required, it points to a subnet in the virtual network provided in the "virtual_network_resource_id" variable.
DESCRIPTION
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
    name        = optional(string)
    subnet_name = string
    forwarding_ruleset = optional(map(object({
      name                                          = optional(string)
      link_with_outbound_endpoint_virtual_network   = optional(bool, true)
      additional_virtual_network_links_resource_ids = optional(set(string), [])
      rules = optional(map(object({
        name                     = optional(string)
        domain_name              = string
        state                    = optional(string, "Enabled")
        destination_ip_addresses = map(string)
      })))
    })))
  }))
  default     = {}
  description = <<DESCRIPTION
A map of outbound endpoints to create on this resource.
- `name` - (Optional) The name for the endpoint 
- `subnet_name` - (Required) The subnet name from the virtual network provided. 
- `forwarding_ruleset` - (Optional) A map of forwarding rulesets to create on the outbound endpoint.
  - `name` - (Optional) The name of the forwarding ruleset
  - `rules` - (Optional) A map of forwarding rules to create on the forwarding ruleset.
    - `name` - (Optional) The name of the forwarding rule
    - `domain_name` - (Required) The domain name to forward
    - `state` - (Optional) The state of the forwarding rule. Possible values are `Enabled` and `Disabled`. Defaults to `Enabled`.
    - `destination_ip_addresses` - (Required) a map of string, the key is the IP address and the value is the port
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
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - The description of the role assignment.
- `skip_service_principal_aad_check` - If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - The condition which will be used to scope the role assignment.
- `condition_version` - The version of the condition syntax. Valid values are '2.0'.

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
