# This exmaple deploys a private DNS resolver with an inbound endpoint, two outbound endpoints, forwarding rulesets and rules, and aditional vnet links.


locals {
  inbound_subnet_name   = "subnet-test-resolver-inbound"
  location              = "northeurope"
  outbound2_subnet_name = "subnet-test-resolver-outbound2"
  outbound_subnet_name  = "subnet-test-resolver-outbound"
}

data "azapi_client_config" "current" {}

resource "azapi_resource" "rg" {
  location  = local.location
  name      = "rg-resolver-vnet-link"
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
resource "azapi_resource" "vnet1" {
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
        },
        {
          name = local.outbound_subnet_name
          properties = {
            addressPrefix = "10.0.1.0/24"
          }
        },
        {
          name = local.outbound2_subnet_name
          properties = {
            addressPrefix = "10.0.2.0/24"
          }
        }
      ]
    }
  }
  response_export_values = []
}

resource "azapi_resource" "vnet2" {
  location  = local.location
  name      = "vnet-test-resolver2"
  parent_id = azapi_resource.rg.id
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = ["10.90.0.0/16"]
      }
    }
  }
  response_export_values = []
}

module "private_resolver" {
  source = "../../" # Replace source with the following line

  location                    = local.location
  name                        = "resolver"
  resource_group_name         = azapi_resource.rg.name
  virtual_network_resource_id = azapi_resource.vnet1.id
  enable_telemetry            = var.enable_telemetry
  inbound_endpoints = {
    "inbound1" = {
      name        = "inbound1"
      subnet_name = local.inbound_subnet_name
      tags = {
        "source" = "onprem"
      }

    }
  }
  outbound_endpoints = {
    "outbound1" = {
      name = "outbound1"
      tags = {
        "destination" = "onprem"
      }
      merge_with_module_tags = false
      subnet_name            = local.outbound_subnet_name
      forwarding_ruleset = {
        "ruleset1" = {
          name = "ruleset1"
          tags = {
            "rules" = "internet"
          }
          merge_with_module_tags = true
          additional_virtual_network_links = {
            "vnet2" = {
              vnet_id = azapi_resource.vnet2.id
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
              destination_ip_addresses = {
                "10.1.1.1" = "53"
                "10.1.1.2" = "53"
              }
            },
            "rule2" = {
              name        = "rule2"
              domain_name = "example2.com."
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
      subnet_name = local.outbound2_subnet_name
    }
  }
  tags = {
    "environment" = "test"
  }
}
