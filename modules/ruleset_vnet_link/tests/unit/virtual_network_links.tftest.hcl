mock_provider "azurerm" {}
mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "terraform" {}

variables {
  dns_forwarding_ruleset_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/dnsForwardingRulesets/ruleset"
  location                  = "northeurope"
  virtual_networks = {
    spoke = {
      vnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/spoke"
      metadata = { purpose = "spoke" }
    }
  }
}

run "virtual_network_links" {
  command = apply

  providers = {
    azurerm   = azurerm
    azapi     = azapi
    terraform = terraform
  }

  assert {
    condition     = azurerm_private_dns_resolver_virtual_network_link.this["spoke"].dns_forwarding_ruleset_id == var.dns_forwarding_ruleset_id && azurerm_private_dns_resolver_virtual_network_link.this["spoke"].virtual_network_id == var.virtual_networks["spoke"].vnet_id
    error_message = "Each virtual network link must target the supplied ruleset and virtual network."
  }
  assert {
    condition     = azurerm_private_dns_resolver_virtual_network_link.this["spoke"].metadata["purpose"] == "spoke"
    error_message = "Virtual network link metadata must be preserved."
  }
}

run "invalid_ruleset_id" {
  command = plan

  providers = {
    azurerm   = azurerm
    azapi     = azapi
    terraform = terraform
  }

  variables {
    dns_forwarding_ruleset_id = "not-a-resource-id"
  }

  expect_failures = [var.dns_forwarding_ruleset_id]
}

run "direct_child_vnet2_output" {
  command = apply

  providers = {
    azurerm   = azurerm
    azapi     = azapi
    terraform = terraform
  }

  variables {
    virtual_networks = {
      vnet2 = {
        vnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/vnet2"
        metadata = { type = "spoke", env = "dev" }
      }
    }
  }

  assert {
    condition     = output.resource_id["vnet2"] == azurerm_private_dns_resolver_virtual_network_link.this["vnet2"].id && azurerm_private_dns_resolver_virtual_network_link.this["vnet2"].dns_forwarding_ruleset_id == var.dns_forwarding_ruleset_id && azurerm_private_dns_resolver_virtual_network_link.this["vnet2"].virtual_network_id == var.virtual_networks["vnet2"].vnet_id && azurerm_private_dns_resolver_virtual_network_link.this["vnet2"].metadata == var.virtual_networks["vnet2"].metadata
    error_message = "The direct child link must expose vnet2 and retain its ruleset, virtual network, and metadata."
  }
}

run "telemetry_enabled" {
  command = apply

  providers = {
    azurerm   = azurerm
    azapi     = azapi
    terraform = terraform
  }

  variables {
    enable_telemetry = true
  }

  assert {
    condition     = length(azapi_resource.telemetry) == 1 && length(data.azapi_client_config.telemetry) == 1 && length(terraform_data.telemetry) == 1
    error_message = "Enabled telemetry must create the child telemetry resources."
  }
}

run "telemetry_disabled" {
  command = apply

  providers = {
    azurerm   = azurerm
    azapi     = azapi
    terraform = terraform
  }

  variables {
    enable_telemetry = false
  }

  assert {
    condition     = length(azapi_resource.telemetry) == 0 && length(data.azapi_client_config.telemetry) == 0 && length(terraform_data.telemetry) == 0
    error_message = "Disabled telemetry must not create child telemetry resources."
  }
}
