provider "azurerm" {
  features {}
  
}

resource "azurerm_resource_group" "name" {
    name = "rg-test-resolver"
    location = "northeurope"
  
}

resource "azurerm_virtual_network" "name" {
    name = "vnet-test-resolver"
    location = "northeurope"
    resource_group_name = azurerm_resource_group.name.name
    address_space = ["10.0.0.0/16"]
  
}

resource "azurerm_subnet" "name" {
    name = "subnet-test-resolver-inbound"
    resource_group_name = azurerm_resource_group.name.name
    virtual_network_name = azurerm_virtual_network.name.name
    address_prefixes = ["10.0.0.0/24"]
    lifecycle {
      ignore_changes = [ delegation ]
    }
}

resource "azurerm_subnet" "out" {
    name = "subnet-test-resolver-outbound"
    resource_group_name = azurerm_resource_group.name.name
    virtual_network_name = azurerm_virtual_network.name.name
    address_prefixes = ["10.0.1.0/24"]
        lifecycle {
      ignore_changes = [ delegation ]
    }
  
}

resource "azurerm_subnet" "out2" {
    name = "subnet-test-resolver-outbound2"
    resource_group_name = azurerm_resource_group.name.name
    virtual_network_name = azurerm_virtual_network.name.name
    address_prefixes = ["10.0.2.0/24"]
        lifecycle {
      ignore_changes = [ delegation ]
    }
  
}

module "private_resolver" {
    source = "../"
    resource_group_name = azurerm_resource_group.name.name
    name = "resolver"
    virtual_network_id = azurerm_virtual_network.name.id
    inbound_endpoints = {
    "inbound1" = {
        name = "inbound1"
        subnet_name = azurerm_subnet.name.name
        
    }
    }
    outbound_endpoints = {
    "outbound1" = {
      name = "outbound1"
      subnet_name = azurerm_subnet.out.name      
      forwarding_ruleset = {
        "ruleset1" = {
          name = "ruleset1"
          additional_virtual_network_links = ["/subscriptions/50828fec-245c-4755-a5d3-de3412c42898/resourceGroups/rg-linuxhost/providers/Microsoft.Network/virtualNetworks/LinuxHost-vnet"]
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
      subnet_name = azurerm_subnet.out2.name
    }
  }
}