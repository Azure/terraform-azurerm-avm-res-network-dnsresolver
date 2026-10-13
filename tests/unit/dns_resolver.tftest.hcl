mock_provider "azurerm" {
  mock_resource "azurerm_private_dns_resolver" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/dnsResolvers/test"
    }
  }
  mock_resource "azurerm_private_dns_resolver_outbound_endpoint" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/dnsResolvers/test/outboundEndpoints/outbound"
    }
  }
  mock_resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/dnsForwardingRulesets/ruleset"
    }
  }
}
mock_provider "azapi" {}
mock_provider "modtm" {}
mock_provider "random" {}

variables {
  location                    = "northeurope"
  name                        = "test"
  resource_group_name         = "test"
  virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test"
  enable_telemetry            = false
}

run "defaults" {
  command = apply

  providers = {
    azurerm = azurerm
    azapi   = azapi
    modtm   = modtm
    random  = random
  }

  assert {
    condition     = output.name == "test" && output.resource_id == azurerm_private_dns_resolver.this.id
    error_message = "The resolver name and resource ID must be returned."
  }
  assert {
    condition     = length(output.inbound_endpoints) == 0 && length(output.outbound_endpoints) == 0 && length(output.forwarding_rulesets) == 0
    error_message = "Optional endpoints and rulesets must be absent by default."
  }
  assert {
    condition     = length(modtm_telemetry.telemetry) == 0 && length(azurerm_management_lock.this) == 0 && length(azurerm_role_assignment.dnsresolver) == 0
    error_message = "Disabled telemetry and unconfigured locks and assignments must not create resources."
  }
}

run "telemetry_enabled" {
  command = apply

  providers = {
    azurerm = azurerm
    azapi   = azapi
    modtm   = modtm
    random  = random
  }

  variables {
    enable_telemetry = true
  }

  assert {
    condition     = length(modtm_telemetry.telemetry) == 1 && length(data.azapi_client_config.telemetry) == 1 && length(random_uuid.telemetry) == 1
    error_message = "Enabled telemetry must use the mocked providers."
  }
}

run "endpoints_rules_and_links" {
  command = apply

  providers = {
    azurerm = azurerm
    azapi   = azapi
    modtm   = modtm
    random  = random
  }

  variables {
    tags = { environment = "test" }
    inbound_endpoints = {
      inbound = {
        subnet_name                  = "inbound"
        private_ip_allocation_method = "Static"
        private_ip_address           = "10.0.0.4"
        tags                         = { endpoint = "inbound" }
      }
    }
    outbound_endpoints = {
      outbound = {
        subnet_name = "outbound"
        forwarding_ruleset = {
          first = {
            name = "ruleset"
            additional_virtual_network_links = {
              spoke = {
                vnet_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/spoke"
                metadata = { purpose = "spoke" }
              }
            }
            rules = {
              example = {
                domain_name              = "example.com."
                destination_ip_addresses = { "10.1.0.4" = "53" }
                enabled                  = false
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = output.inbound_endpoint_ips["inbound"] == "10.0.0.4" && output.inbound_endpoints["inbound"].tags == tomap({ environment = "test", endpoint = "inbound" })
    error_message = "The static inbound address and merged endpoint tags must be preserved."
  }
  assert {
    condition     = azurerm_private_dns_resolver_forwarding_rule.this["outbound-ruleset-example"].domain_name == "example.com." && !azurerm_private_dns_resolver_forwarding_rule.this["outbound-ruleset-example"].enabled
    error_message = "Forwarding rules must retain their domain and enabled setting."
  }
  assert {
    condition     = length(azurerm_private_dns_resolver_virtual_network_link.default) == 1 && azurerm_private_dns_resolver_virtual_network_link.additional["outbound-ruleset-spoke"].metadata["purpose"] == "spoke"
    error_message = "Default and additional virtual network links must be created with their metadata."
  }
}

run "optional_rules" {
  command = apply

  providers = {
    azurerm = azurerm
    azapi   = azapi
    modtm   = modtm
    random  = random
  }

  variables {
    outbound_endpoints = {
      outbound = {
        subnet_name = "outbound"
        forwarding_ruleset = {
          empty = {}
        }
      }
    }
  }

  assert {
    condition     = length(output.forwarding_rulesets) == 1 && length(azurerm_private_dns_resolver_forwarding_rule.this) == 0
    error_message = "A forwarding ruleset must support omitting its optional rules."
  }
}

run "locks_and_role_assignments" {
  command = apply

  providers = {
    azurerm = azurerm
    azapi   = azapi
    modtm   = modtm
    random  = random
  }

  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-000000000001"
        description                = "DNS reader"
        principal_type             = "ServicePrincipal"
      }
    }
    outbound_endpoints = {
      outbound = {
        subnet_name = "outbound"
        forwarding_ruleset = {
          first = {
            name  = "ruleset"
            rules = {}
          }
        }
      }
    }
  }

  assert {
    condition     = azurerm_management_lock.this[0].scope == output.resource_id && length(azurerm_management_lock.rulesets) == 1
    error_message = "Locks must protect the resolver and its forwarding rulesets."
  }
  assert {
    condition     = azurerm_role_assignment.dnsresolver["reader"].description == "DNS reader" && azurerm_role_assignment.dnsresolver["reader"].principal_type == "ServicePrincipal"
    error_message = "Resolver role assignments must retain their description and principal type."
  }
  assert {
    condition     = length(azurerm_role_assignment.rulesets) == 1 && azurerm_role_assignment.rulesets["0"].role_definition_name == "Reader" && azurerm_role_assignment.rulesets["0"].principal_type == "ServicePrincipal"
    error_message = "The existing ruleset assignment address and role must be preserved."
  }
}

run "invalid_lock" {
  command = plan

  providers = {
    azurerm = azurerm
    azapi   = azapi
    modtm   = modtm
    random  = random
  }

  variables {
    lock = { kind = "Invalid" }
  }

  expect_failures = [var.lock]
}

run "invalid_name" {
  command = plan

  providers = {
    azurerm = azurerm
    azapi   = azapi
    modtm   = modtm
    random  = random
  }

  variables {
    name = ""
  }

  expect_failures = [var.name]
}
