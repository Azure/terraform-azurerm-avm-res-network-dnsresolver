terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">=3.5"
    }
  }

}

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

module "private_resolver" {
    source = "../../"
    resource_group_name = azurerm_resource_group.name.name
    name = "resolver"
    virtual_network_id = azurerm_virtual_network.name.id
    inbound_endpoints = {
    "inbound1" = {
        name = "inbound1"
        subnet_name = azurerm_subnet.name.name 
    }
  }
}