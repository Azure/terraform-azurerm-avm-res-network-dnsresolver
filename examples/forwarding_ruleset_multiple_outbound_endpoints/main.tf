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
