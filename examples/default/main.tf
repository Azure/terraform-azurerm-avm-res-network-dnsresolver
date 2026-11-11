# This example deploys the private DNS resolver into a subnet with a single inbound endpoint

locals {
  inbound_subnet_name = "subnet-test-resolver-inbound"
  location            = "northeurope"
}

data "azapi_client_config" "current" {}

resource "azapi_resource" "rg" {
  location  = local.location
  name      = "rg-test-resolver-simple"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type      = "Microsoft.Resources/resourceGroups@2025-04-01"
  body = {
    properties = {}
  }
  response_export_values = []
}

resource "azapi_resource" "vnet" {
  location  = local.location
  name      = "vnet-test-resolver"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.0.0.0/16"]
      }
      subnets = [
        {
          name = local.inbound_subnet_name
          properties = {
            addressPrefix = "10.0.0.0/24"
          }
        }
      ]
    }
  }
  response_export_values = []
}

module "private_resolver" {
  source = "../../" # Replace source with the following line

  location = local.location
  name     = "resolver"
  #source  = "Azure/avm-res-network-dnsresolver/azurerm"
  parent_id                   = azapi_resource.rg.id
  virtual_network_resource_id = azapi_resource.vnet.id
  enable_telemetry            = var.enable_telemetry
  inbound_endpoints = {
    "inbound1" = {
      name        = "inbound1"
      subnet_name = local.inbound_subnet_name
    }
  }
}
