<!-- BEGIN_TF_DOCS -->
# Outbound Endpoint VNet Links Example

This example shows how to create an outbound endpoint with VNet links.

```hcl
# This exmaple deploys a private DNS resolver with an inbound endpoint, two outbound endpoints, forwarding rulesets and rules, and aditional vnet links.


locals {
  location = "northeurope"
}

resource "azurerm_resource_group" "rg" {
  location = local.location
  name     = "rg-resolver-ruleset-links"
}

resource "azurerm_virtual_network" "vnet1" {
  location            = local.location
  name                = "vnet-test-resolver"
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "name" {
  address_prefixes     = ["10.0.0.0/24"]
  name                 = "subnet-test-resolver-inbound"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name

  lifecycle {
    ignore_changes = [delegation]
  }
}

resource "azurerm_subnet" "out" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "subnet-test-resolver-outbound"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name

  lifecycle {
    ignore_changes = [delegation]
  }
}

resource "azurerm_subnet" "out2" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "subnet-test-resolver-outbound2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name

  lifecycle {
    ignore_changes = [delegation]
  }
}

module "private_resolver" {
  source = "../../" # Replace source with the following line

  location                    = local.location
  name                        = "resolver"
  resource_group_name         = azurerm_resource_group.rg.name
  virtual_network_resource_id = azurerm_virtual_network.vnet1.id
  inbound_endpoints = {
    "inbound1" = {
      name        = "inbound1"
      subnet_name = azurerm_subnet.name.name
      tags = {
        "source" = "onprem"
      }
      merge_with_module_tags = false
    }
  }
  outbound_endpoints = {
    "outbound1" = {
      name        = "outbound1"
      subnet_name = azurerm_subnet.out.name
      tags = {
        "destination" = "onprem"
      }
      merge_with_module_tags = true
      forwarding_ruleset = {
        "ruleset1" = {
          tags = {
            "environment" = "test"
          }
          merge_with_module_tags = false
          name                   = "ruleset1"
          additional_outbound_endpoint_link = {
            outbound_endpoint_key = "outbound2"
          }
          additional_virtual_network_links = {
            "vnet2" = {
              vnet_id = azurerm_virtual_network.vnet2.id
              metadata = {
                "type" = "spoke"
                "env"  = "dev"
              }
            }
          }
          rules = {
            "rule1" = {
              name        = "rule1"
              domain_name = "example.com."
              state       = "Enabled"
              destination_ip_addresses = {
                "10.1.1.1" = "53"
                "10.1.1.2" = "53"
              }
            },
            "rule2" = {
              name        = "rule2"
              domain_name = "example2.com."
              state       = "Enabled"
              destination_ip_addresses = {
                "10.2.2.2" = "53"
              }
            }
          }
        }
      }
    }
    "outbound2" = {
      name        = "outbound2"
      subnet_name = azurerm_subnet.out2.name
    }
  }
  #source  = "Azure/avm-res-network-dnsresolver/azurerm"
  tags = {
    "created_by" = "terraform"
  }
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.9, < 2.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.0)

## Resources

The following resources are used by this module:

- [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.name](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet.out](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_subnet.out2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.vnet1](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

No optional inputs.

## Outputs

No outputs.

## Modules

The following Modules are called:

### <a name="module_private_resolver"></a> [private\_resolver](#module\_private\_resolver)

Source: ../../

Version:

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->