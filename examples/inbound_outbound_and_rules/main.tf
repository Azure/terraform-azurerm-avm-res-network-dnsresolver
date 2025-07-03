# This exmaple deploys a private DNS resolver with an inbound endpoint, two outbound endpoints, forwarding rulesets and rules.

resource "azurerm_resource_group" "name" {
  location = "northeurope"
  name     = "rg-test-resolver-outbound-rules"
}

resource "azurerm_virtual_network" "name" {
  location            = "northeurope"
  name                = "vnet-test-resolver"
  resource_group_name = azurerm_resource_group.name.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "name" {
  address_prefixes     = ["10.0.0.0/24"]
  name                 = "subnet-test-resolver-inbound"
  resource_group_name  = azurerm_resource_group.name.name
  virtual_network_name = azurerm_virtual_network.name.name

  lifecycle {
    ignore_changes = [delegation]
  }
}

resource "azurerm_subnet" "out" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "subnet-test-resolver-outbound"
  resource_group_name  = azurerm_resource_group.name.name
  virtual_network_name = azurerm_virtual_network.name.name

  lifecycle {
    ignore_changes = [delegation]
  }
}

resource "azurerm_subnet" "out2" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "subnet-test-resolver-outbound2"
  resource_group_name  = azurerm_resource_group.name.name
  virtual_network_name = azurerm_virtual_network.name.name

  lifecycle {
    ignore_changes = [delegation]
  }
}

module "private_resolver" {
  source = "../../" # Replace source with the following line

  location = "northeurope"
  name     = "resolver"
  #source  = "Azure/avm-res-network-dnsresolver/azurerm"
  resource_group_name         = azurerm_resource_group.name.name
  virtual_network_resource_id = azurerm_virtual_network.name.id
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