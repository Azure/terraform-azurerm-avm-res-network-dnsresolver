
# This example deploys the private DNS resolver into a subnet with a single inbound endpoint

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    # TODO: Ensure all required providers are listed here.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.71.0, < 4.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "name" {
  location = "northeurope"
  name     = "rg-test-resolver-simple"
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
  source = "../../" # Replace source with the following line
  #source  = "Azure/avm-res-network-dnsresolver/azurerm"
  resource_group_name         = azurerm_resource_group.name.name
  name                        = "resolver"
  virtual_network_resource_id = azurerm_virtual_network.name.id
  location                    = "northeurope"
  inbound_endpoints = {
    "inbound1" = {
      name        = "inbound1"
      subnet_name = azurerm_subnet.name.name
    }
  }
}