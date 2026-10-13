mock_provider "azurerm" {}
mock_provider "azapi" {}

variables {
  dns_forwarding_ruleset_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/dnsForwardingRulesets/ruleset"
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
    azurerm = azurerm
    azapi   = azapi
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
    azurerm = azurerm
    azapi   = azapi
  }

  variables {
    dns_forwarding_ruleset_id = "not-a-resource-id"
  }

  expect_failures = [var.dns_forwarding_ruleset_id]
}
