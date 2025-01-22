<!-- BEGIN_TF_DOCS -->
# Azure Private DNS Resolver Ruleset VNet Link Module

This is a module for linking existing vnets to an existing forwarding ruleset in an Azure Private DNS Resolver outbound endpoint.

## Features And Notes
This module is used to link existing vnets to an existing forwarding ruleset in an Azure Private DNS Resolver outbound endpoint. It is usefull when you want to decouple the dns resolver resources from the linking of vnets to the forwarding ruleset. it supports:
- linking a single vnet to a single forwarding ruleset

## Feedback
- Your feedback is welcome! Please raise an issue or feature request on the module's GitHub repository.

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.5.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.0)

- <a name="requirement_modtm"></a> [modtm](#requirement\_modtm) (~> 0.3)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0)

## Resources

The following resources are used by this module:

- [azurerm_private_dns_resolver_virtual_network_link.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver_virtual_network_link) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_dns_forwarding_ruleset_id"></a> [dns\_forwarding\_ruleset\_id](#input\_dns\_forwarding\_ruleset\_id)

Description: The ID of the DNS forwarding ruleset to link to the virtual networks.

Type: `string`

### <a name="input_virtual_networks"></a> [virtual\_networks](#input\_virtual\_networks)

Description: A map virtual network links to create.
  - `vnet_id` - (Required) The ID of the virtual network to link to.
  - `metadata` - (Optional) A map of metadata to associate with the virtual network link.

Type:

```hcl
map(object({
    vnet_id = string
  metadata = optional(map(string), null) }))
```

## Optional Inputs

No optional inputs.

## Outputs

No outputs.

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->