terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.5"
    }
  }

}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "name" {
  location = "northeurope"
  name     = "rg-test-resolver"
}

resource "azurerm_virtual_network" "name" {
  address_space       = ["10.0.0.0/16"]
  location            = "northeurope"
  name                = "vnet-test-resolver"
  resource_group_name = azurerm_resource_group.name.name
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

module "private_resolver" {
  source                      = "../../"
  resource_group_name         = azurerm_resource_group.name.name
  name                        = "resolver"
  virtual_network_resource_id = azurerm_virtual_network.name.id
  inbound_endpoints = {
    "inbound1" = {
      name        = "inbound1"
      subnet_name = azurerm_subnet.name.name
    }
  }
}