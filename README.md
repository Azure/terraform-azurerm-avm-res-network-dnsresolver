<!-- BEGIN_TF_DOCS -->
# terraform-azurerm-avm-res-network-dnsresolver

This is a module for deploying private dns resolver. It can be used to deploy the reosolver, inbound endpoints, outbound endpoints, forwarding rulesets and rules.

> [!IMPORTANT]
> As the overall AVM framework is not GA (generally available) yet - the CI framework and test automation is not fully functional and implemented across all supported languages yet - breaking changes are expected, and additional customer feedback is yet to be gathered and incorporated. Hence, modules **MUST NOT** be published at version `1.0.0` or higher at this time.
>
> All module **MUST** be published as a pre-release version (e.g., `0.1.0`, `0.1.1`, `0.2.0`, etc.) until the AVM framework becomes GA.
>
> However, it is important to note that this **DOES NOT** mean that the modules cannot be consumed and utilized. They **CAN** be leveraged in all types of environments (dev, test, prod etc.). Consumers can treat them just like any other IaC module and raise issues or feature requests against them as they learn from the usage of the module. Consumers should also read the release notes for each version, if considering updating to a more recent version of a module to see if there are any considerations or breaking changes etc.

## Features And Notes
- This module deploys a private dns resolver and optional inbound and outbound endpoints.
- It also deploys optional forwarding rulesets and rules for outbound endpoints.
- An existing virtual network with appropriately sized **empty** subnets is required.
- For information on the Azure Private DNS Resolver service, see [Private DNS Resolver](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview).
- For information on how to configure subnets for the resolver, see [Inbound Endpoints](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview#inbound-endpoints) and [Outbound Endpoints](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview#outbound-endpoints).

## Feedback
- Your feedback is welcome! Please raise an issue or feature request on the module's GitHub repository.

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9, < 2.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.0)

- <a name="requirement_modtm"></a> [modtm](#requirement\_modtm) (~> 0.3)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0)

## Resources

The following resources are used by this module:

- [azurerm_management_lock.rulesets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_management_lock.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_private_dns_resolver.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver) (resource)
- [azurerm_private_dns_resolver_dns_forwarding_ruleset.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver_dns_forwarding_ruleset) (resource)
- [azurerm_private_dns_resolver_forwarding_rule.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver_forwarding_rule) (resource)
- [azurerm_private_dns_resolver_inbound_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver_inbound_endpoint) (resource)
- [azurerm_private_dns_resolver_outbound_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver_outbound_endpoint) (resource)
- [azurerm_private_dns_resolver_virtual_network_link.additional](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver_virtual_network_link) (resource)
- [azurerm_private_dns_resolver_virtual_network_link.default](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver_virtual_network_link) (resource)
- [azurerm_role_assignment.dnsresolver](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_assignment.rulesets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [modtm_telemetry.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/resources/telemetry) (resource)
- [random_uuid.telemetry](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) (resource)
- [terraform_data.outbound](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) (resource)
- [azapi_client_config.telemetry](https://registry.terraform.io/providers/hashicorp/azapi/latest/docs/data-sources/client_config) (data source)
- [modtm_module_source.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/data-sources/module_source) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_location"></a> [location](#input\_location)

Description: Azure region where the resource should be deployed.

Type: `string`

### <a name="input_name"></a> [name](#input\_name)

Description: The name of the dns resolver.

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The resource group where the resources will be deployed.

Type: `string`

### <a name="input_virtual_network_resource_id"></a> [virtual\_network\_resource\_id](#input\_virtual\_network\_resource\_id)

Description: The ID of the virtual network to deploy the inbound and outbound endpoints into. The vnet should have appropriate subnets for the endpoints.  
For more information on how to configure subnets for inbound and outbounbd endpoints, see the modules readme.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see <https://aka.ms/avm/telemetryinfo>.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_inbound_endpoints"></a> [inbound\_endpoints](#input\_inbound\_endpoints)

Description: A map of inbound endpoints to create for this DNS resolver.

- `name` - (Optional) The name of the inbound endpoint.
- `subnet_name` - (Required) The name of the subnet within the virtual network specified by `virtual_network_resource_id` where the inbound endpoint will be deployed.
- `private_ip_allocation_method` - (Optional) The allocation method for the private IP address. Possible values are `Dynamic` (default) or `Static`.
- `private_ip_address` - (Optional) The static private IP address to assign if `private_ip_allocation_method` is set to `Static`.
- `tags` - (Optional) A map of tags to assign to the inbound endpoint.
- `merge_with_module_tags` - (Optional) Whether to merge the module tags with the inbound endpoint tags. Defaults to true.

Multiple inbound endpoints can be created by providing multiple entries in the map.

Type:

```hcl
map(object({
    name                         = optional(string)
    subnet_name                  = string
    private_ip_allocation_method = optional(string, "Dynamic")
    private_ip_address           = optional(string, null)
    tags                         = optional(map(string), null)
    merge_with_module_tags       = optional(bool, true)
  }))
```

Default: `{}`

### <a name="input_lock"></a> [lock](#input\_lock)

Description:   Controls the Resource Lock configuration for this resource. The following properties can be specified:

  - `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
  - `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.

Type:

```hcl
object({
    kind = string
    name = optional(string, null)
  })
```

Default: `null`

### <a name="input_outbound_endpoints"></a> [outbound\_endpoints](#input\_outbound\_endpoints)

Description: A map of outbound endpoints to create on this resource.

- `name` - (Optional) The name for the endpoint.
- `tags` - (Optional) A map of tags to assign to the outbound endpoint.
- `merge_with_module_tags` - (Optional) Whether to merge the module tags with the outbound endpoint tags. Defaults to true.
- `subnet_name` - (Required) The subnet name from the virtual network provided.
- `forwarding_ruleset` - (Optional) A map of forwarding rulesets to create on the outbound endpoint.
  - `name` - (Optional) The name of the forwarding ruleset.
  - `link_with_outbound_endpoint_virtual_network` - (Optional) Whether to link the outbound endpoint with the hosting virtual network. Defaults to true.
  - `metadata_for_outbound_endpoint_virtual_network_link` - (Optional) A map of metadata to associate with the virtual network link.
  - `tags` - (Optional) A map of tags to assign to the forwarding ruleset.
  - `merge_with_module_tags` - (Optional) Whether to merge the module tags with the forwarding ruleset tags. Defaults to true.
  - `additional_virtual_network_links` - (Optional) A map of additional virtual network links to create.
    - `name` - (Optional) The name of the additional virtual network link.
    - `vnet_id` - (Required) The ID of the virtual network to link to.
    - `metadata` - (Optional) A map of metadata to associate with the virtual network link.
  - `rules` - (Optional) A map of forwarding rules to create on the forwarding ruleset.
    - `name` - (Optional) The name of the forwarding rule.
    - `domain_name` - (Required) The domain name to forward.
    - `destination_ip_addresses` - (Required) A map of string, the key is the IP address and the value is the port.
    - `enabled` - (Optional) Whether the forwarding rule is enabled. Defaults to true.
    - `metadata` - (Optional) A map of metadata to associate with the forwarding rule.

Type:

```hcl
map(object({
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
```

Default: `{}`

### <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments)

Description:   A map of role assignments to create on the <RESOURCE>. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

  - `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
  - `principal_id` - The ID of the principal to assign the role to.
  - `description` - (Optional) The description of the role assignment.
  - `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
  - `condition` - (Optional) The condition which will be used to scope the role assignment.
  - `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
  - `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
  - `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

  > Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.

Type:

```hcl
map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: (Optional) Tags of the resource.

Type: `map(string)`

Default: `null`

## Outputs

The following outputs are exported:

### <a name="output_forwarding_rulesets"></a> [forwarding\_rulesets](#output\_forwarding\_rulesets)

Description: The forwarding rulesets of the DNS resolver.

### <a name="output_inbound_endpoint_ips"></a> [inbound\_endpoint\_ips](#output\_inbound\_endpoint\_ips)

Description: The IP addresses of the inbound endpoints.

### <a name="output_inbound_endpoints"></a> [inbound\_endpoints](#output\_inbound\_endpoints)

Description: The inbound endpoints of the DNS resolver.

### <a name="output_name"></a> [name](#output\_name)

Description: The name of the DNS resolver.

### <a name="output_outbound_endpoints"></a> [outbound\_endpoints](#output\_outbound\_endpoints)

Description: The outbound endpoints of the DNS resolver.

### <a name="output_resource"></a> [resource](#output\_resource)

Description: This is the full output for the resource.

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: The ID of the DNS resolver.

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->