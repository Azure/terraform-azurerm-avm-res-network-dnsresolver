variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

# This is required for most resource modules
variable "resource_group_name" {
  type        = string
  description = "The resource group where the resources will be deployed."
}

variable "location" {
  type        = string
  description = "Azure region where the resource should be deployed.  If null, the location will be inferred from the resource group location."
  default     = null
}

variable "name" {
  type        = string
  description = "The name of the this resource."
  validation {
    condition     = can(regex("^[^#]+$", var.name))
    error_message = "The name must be at least 1 characters long."
  }
}

# required AVM interfaces
# remove only if not supported by the resource
# tflint-ignore: terraform_unused_declarations
variable "customer_managed_key" {
  type = object({
    key_vault_resource_id              = optional(string)
    key_name                           = optional(string)
    key_version                        = optional(string, null)
    user_assigned_identity_resource_id = optional(string, null)
  })
  description = "Customer managed keys that should be associated with the resource."
  default     = {}
}

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
  description = <<DESCRIPTION
A map of diagnostic settings to create on the Key Vault. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
- `log_categories` - (Optional) A set of log categories to send to the log analytics workspace. Defaults to `[]`.
- `log_groups` - (Optional) A set of log groups to send to the log analytics workspace. Defaults to `["allLogs"]`.
- `metric_categories` - (Optional) A set of metric categories to send to the log analytics workspace. Defaults to `["AllMetrics"]`.
- `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
- `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
- `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic LogsLogs.
DESCRIPTION
}

variable "lock" {
  type = object({
    name = optional(string, null)
    kind = optional(string, "None")
  })
  description = "The lock level to apply. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`."
  default     = {}
  nullable    = false
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly", "None"], var.lock.kind)
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  description = "Managed identities to be created for the resource."
  default     = {}
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
}

# tflint-ignore: terraform_unused_declarations
variable "tags" {
  type        = map(any)
  description = "The map of tags to be applied to the resource"
  default     = {}
}

variable "virtual_network_id" {
  type        = string
  description = "The ID of the virtual network to deploy the private DNS resolver in."
}

variable "inbound_endpoints" {
  type = map(object({
    name = string
    subnet_name = string
  }))
  default     = {}
  description = <<DESCRIPTION
A map of inbound endpoints to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
DESCRIPTION
}

# variable "outbound_endpoints" {
#   type = map(string)
#   default     = {}
#   description = <<DESCRIPTION
# A map of outbound endpoints to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
# - The key is the name for the endpoint
# - The value is the subnet ID
# DESCRIPTION
# }

variable "outbound_endpoints" {
  type = map(object({
    name = string
    subnet_name = string
    forwarding_ruleset = optional(map(object({
      name = string
      link_with_outbound_endpoint_virtual_network = optional(bool, true)
      additional_virtual_network_links = optional(set(string), [])
      rules = optional(map(object({
        name = string
        domain_name = string
        state = optional(string, "Enabled")
        destination_ip_addresses = map(string)
      })))
    })))
  }))
  description = <<DESCRIPTION
A map of outbound endpoints to create on this resource. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
- `name` - The name for the endpoint
- `subnet_name` - The subnet name from the virtual network provided
- `forwarding_ruleset` - (Optional) A map of forwarding rulesets to create on the outbound endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
  - `name` - The name of the forwarding ruleset
  - `rules` - (Optional) A map of forwarding rules to create on the forwarding ruleset. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
    - `name` - The name of the forwarding rule
    - `domain_name` - The domain name to forward
    - `state` - (Optional) The state of the forwarding rule. Possible values are `Enabled` and `Disabled`. Defaults to `Enabled`.
    - `destination_ip_addresses - a map of string, the key is the IP address and the value is the port
DESCRIPTION
 default = {
    "outbound1" = {
      name = "outbound1"
      subnet_name = "sub1"
      forwarding_ruleset = {
        "ruleset1" = {
          name = "ruleset1"
          link_with_outboutnd_endpoint_virtual_network = true
          additional_virtual_network_links = ["vnet1", "vnet2"]
          rules = {
            "rule1" = {
              name = "rule1"
              domain_name = "example.com."
              state = "Enabled"
              destination_ip_addresses = {
                "10.1.1.1" = "53"
                "10.1.1.2" = "53"
              }
            },
            "rule2" = {
              name = "rule2"
              domain_name = "example2.com."
              state = "Enabled"
              destination_ip_addresses = {
                "10.2.2.2" = "53"
              }
            }

          }
        }
      }
    }
    "outbound2" = {
      name = "outbound2"
      subnet_name = "sub2"
    }
  }
}
