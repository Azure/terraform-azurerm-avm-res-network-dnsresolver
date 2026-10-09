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

# Subnets are declared inline in the virtual network body rather than as separate child
# resources. One PUT avoids the `AnotherOperationInProgress` conflicts that concurrent subnet
# writes cause, and AzAPI only tracks the body properties that are declared here, so the
# delegation the DNS resolver service adds to the outbound subnets never shows up as drift.
# That replaces the `lifecycle { ignore_changes = [delegation] }` the AzureRM example needed.
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
  resource_group_name         = azapi_resource.rg.name
  virtual_network_resource_id = azapi_resource.vnet.id
  enable_telemetry            = var.enable_telemetry
  inbound_endpoints = {
    "inbound1" = {
      name        = "inbound1"
      subnet_name = local.inbound_subnet_name
    }
  }
}
