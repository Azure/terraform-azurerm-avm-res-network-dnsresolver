
# This example deploys the private DNS resolver into a subnet with a single inbound endpoint

resource "azurerm_resource_group" "name" {
  location = "northeurope"
  name     = "rg-test-resolver-simple"
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
}