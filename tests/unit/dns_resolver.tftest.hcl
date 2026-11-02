mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000001"
    }
  }
}

mock_provider "random" {}

mock_provider "terraform" {}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/dnsResolvers/test"
  }
}

override_resource {
  target = azapi_resource.outbound_endpoint
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/dnsResolvers/test/outboundEndpoints/outbound"
  }
}

override_resource {
  target = azapi_resource.inbound_endpoint
  values = {
    output = {
      properties = {
        ipConfigurations = [{
          privateIpAddress          = "10.0.0.4"
          privateIpAllocationMethod = "Static"
          subnet = {
            id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/inbound"
          }
        }]
      }
    }
  }
}

override_resource {
  target = azapi_resource.forwarding_ruleset
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/dnsForwardingRulesets/ruleset"
  }
}

override_data {
  target = module.interfaces.data.azapi_resource_list.role_definitions[0]
  values = {
    output = {
      results = [{
        id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        role_name = "Reader"
      }]
    }
  }
}

variables {
  location                    = "northeurope"
  name                        = "test"
  parent_id                   = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/explicit-scope"
  virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test"
  enable_telemetry            = false
}

run "defaults" {
  command = apply

  providers = {
    azapi     = azapi
    random    = random
    terraform = terraform
  }

  assert {
    condition     = output.name == "test" && output.resource_id == azapi_resource.this.id
    error_message = "The resolver name and resource ID must be returned."
  }
  assert {
    condition     = azapi_resource.this.parent_id == var.parent_id && output.resource.resource_group_name == "explicit-scope"
    error_message = "The resolver must use the caller's known parent ID and preserve its resource-group-name output."
  }
  assert {
    condition     = length(output.inbound_endpoints) == 0 && length(output.outbound_endpoints) == 0 && length(output.forwarding_rulesets) == 0
    error_message = "Optional endpoints and rulesets must be absent by default."
  }
  assert {
    condition     = length(azapi_resource.telemetry) == 0 && length(terraform_data.telemetry) == 0 && length(data.azapi_client_config.telemetry) == 0 && length(azapi_resource.lock) == 0 && length(azapi_resource.role_assignments) == 0
    error_message = "Disabled telemetry and unconfigured locks and assignments must not create resources."
  }
}

run "telemetry_enabled" {
  command = apply

  providers = {
    azapi     = azapi
    random    = random
    terraform = terraform
  }

  variables {
    enable_telemetry = true
  }

  assert {
    condition     = length(azapi_resource.telemetry) == 1 && length(data.azapi_client_config.telemetry) == 1 && length(terraform_data.telemetry) == 1
    error_message = "Enabled telemetry must use the mocked providers."
  }
}

run "endpoints_rules_and_links" {
  command = apply

  providers = {
    azapi     = azapi
    random    = random
    terraform = terraform
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
    condition     = azapi_resource.inbound_endpoint["inbound"].body.properties.ipConfigurations[0].privateIpAddress == "10.0.0.4" && azapi_resource.inbound_endpoint["inbound"].tags == tomap({ environment = "test", endpoint = "inbound" })
    error_message = "The static inbound address and merged endpoint tags must be preserved."
  }
  assert {
    condition     = output.inbound_endpoints["inbound"].ip_configurations[0].private_ip_address == "10.0.0.4" && output.inbound_endpoints["inbound"].ip_configurations[0].private_ip_allocation_method == "Static" && output.inbound_endpoints["inbound"].ip_configurations[0].subnet_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test/subnets/inbound"
    error_message = "Inbound endpoint outputs must retain the nested ip_configurations shape."
  }
  assert {
    condition     = azapi_resource.forwarding_rule["outbound-ruleset-example"].body.properties.domainName == "example.com." && azapi_resource.forwarding_rule["outbound-ruleset-example"].body.properties.forwardingRuleState == "Disabled"
    error_message = "Forwarding rules must retain their domain and enabled setting."
  }
  assert {
    condition     = length(azapi_resource.virtual_network_link_default) == 1 && azapi_resource.virtual_network_link_additional["outbound-ruleset-spoke"].body.properties.metadata["purpose"] == "spoke"
    error_message = "Default and additional virtual network links must be created with their metadata."
  }
}

run "optional_rules" {
  command = apply

  providers = {
    azapi     = azapi
    random    = random
    terraform = terraform
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
    condition     = length(output.forwarding_rulesets) == 1 && length(azapi_resource.forwarding_rule) == 0
    error_message = "A forwarding ruleset must support omitting its optional rules."
  }
}

run "locks_and_role_assignments" {
  command = apply

  providers = {
    azapi     = azapi
    random    = random
    terraform = terraform
  }

  variables {
    ignore_body_changes = {
      authorization_locks            = ["properties.notes"]
      authorization_role_assignments = ["properties.description"]
    }
    lock = { kind = "CanNotDelete" }
    resource_types = {
      authorization_locks            = "Microsoft.Authorization/locks@2016-09-01"
      authorization_role_assignments = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
    }
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
    condition     = azapi_resource.lock[0].parent_id == output.resource_id && length(azapi_resource.lock_rulesets) == 1
    error_message = "Locks must protect the resolver and its forwarding rulesets."
  }
  assert {
    condition     = azapi_resource.lock[0].type == "Microsoft.Authorization/locks@2016-09-01" && azapi_resource.lock_rulesets["outbound-ruleset"].type == "Microsoft.Authorization/locks@2016-09-01"
    error_message = "Resolver and ruleset locks must use the configured lock API version."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].type == "Microsoft.Authorization/roleAssignments@2020-04-01-preview" && azapi_resource.role_assignments_rulesets["0"].type == "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
    error_message = "Resolver and ruleset role assignments must use the configured role-assignment API version."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.description == "DNS reader" && azapi_resource.role_assignments["reader"].body.properties.principalType == "ServicePrincipal"
    error_message = "Resolver role assignments must retain their description and principal type."
  }
  assert {
    condition     = length(azapi_resource.role_assignments_rulesets) == 1 && endswith(azapi_resource.role_assignments_rulesets["0"].body.properties.roleDefinitionId, "acdd72a7-3385-48ef-bd42-f606fba81ae7") && azapi_resource.role_assignments_rulesets["0"].body.properties.principalType == "ServicePrincipal"
    error_message = "The existing ruleset assignment address and role must be preserved."
  }
}

run "invalid_lock" {
  command = plan

  providers = {
    azapi     = azapi
    random    = random
    terraform = terraform
  }

  variables {
    lock = { kind = "Invalid" }
  }

  expect_failures = [var.lock]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "not-a-resource-id"
  }

  expect_failures = [var.parent_id]
  providers = {
    azapi     = azapi
    random    = random
    terraform = terraform
  }
}

run "invalid_name" {
  command = plan

  providers = {
    azapi     = azapi
    random    = random
    terraform = terraform
  }

  variables {
    name = ""
  }

  expect_failures = [var.name]
}
