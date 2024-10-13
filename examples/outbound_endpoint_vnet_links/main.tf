# This exmaple deploys a private DNS resolver with an inbound endpoint, two outbound endpoints, forwarding rulesets and rules, and aditional vnet links.


locals {
  location = "northeurope"
}

resource "azurerm_resource_group" "rg" {
  location = local.location
  name     = "rg-resolver-vnet-links"
}

resource "azurerm_virtual_network" "vnet1" {
  address_space       = ["10.0.0.0/16"]
  location            = local.location
  name                = "vnet-test-resolver"
  resource_group_name = azurerm_resource_group.rg.name
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

resource "azurerm_virtual_network" "vnet2" {
  address_space       = ["10.90.0.0/16"]
  location            = local.location
  name                = "vnet-test-resolver2"
  resource_group_name = azurerm_resource_group.rg.name
}

module "private_resolver" {
  source = "../../" # Replace source with the following line
  #source  = "Azure/avm-res-network-dnsresolver/azurerm"
  resource_group_name         = azurerm_resource_group.rg.name
  name                        = "resolver"
  virtual_network_resource_id = azurerm_virtual_network.vnet1.id
  location                    = local.location
  inbound_endpoints = {
    "inbound1" = {
      name        = "inbound1"
      subnet_name = azurerm_subnet.name.name

    }
  }
  outbound_endpoints = {
    "outbound1" = {
      name        = "outbound1"
      subnet_name = azurerm_subnet.out.name
      forwarding_ruleset = {
        "ruleset1" = {
          name = "ruleset1"
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
}
