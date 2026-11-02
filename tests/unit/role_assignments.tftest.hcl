mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000001"
      tenant_id                = "00000000-0000-0000-0000-000000000002"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001"
    }
  }
}

mock_provider "random" {}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/resolver-test"
  }
}

override_resource {
  target = azapi_resource.outbound_endpoint
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/resolver-test/outboundEndpoints/out-test"
  }
}

override_resource {
  target = azapi_resource.forwarding_ruleset
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/dnsForwardingRulesets/ruleset-test"
  }
}

override_data {

  target = module.interfaces.data.azapi_resource_list.role_definitions[0]
  values = {
    output = {
      results = [
        {
          id        = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-000000000007"
          role_name = "RG Only Custom Role"
        },
        {
          id        = "/subscriptions/00000000-0000-0000-0000-000000000001/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        },
      ]
    }
  }
}

variables {
  name                        = "resolver-test"
  parent_id                   = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test"
  location                    = "eastus"
  virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
  enable_telemetry            = false
  outbound_endpoints = {
    out = {
      subnet_name = "outbound"
      forwarding_ruleset = {
        test = {
          name  = "ruleset-test"
          rules = {}
        }
      }
    }
  }
  role_assignments = {
    custom = {
      role_definition_id_or_name = "RG Only Custom Role"
      principal_id               = "00000000-0000-0000-0000-000000000004"
    }
  }
}

run "resolves_role_names_through_the_lookup" {
  command = apply

  assert {
    condition     = azapi_resource.role_assignments["custom"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000001/resourcegroups/rg-test/providers/microsoft.authorization/roledefinitions/00000000-0000-0000-0000-000000000007"
    error_message = "A role name that only exists at the resource group must resolve to that role definition id on the resolver assignment."
  }

  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].body.properties.roleDefinitionId == azapi_resource.role_assignments["custom"].body.properties.roleDefinitionId
    error_message = "The forwarding ruleset assignment must send the same resolved role definition id as the resolver assignment."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "sends_service_principal_type_when_skip_check_is_true" {
  command = apply

  variables {
    role_assignments = {
      skip = {
        role_definition_id_or_name       = "Reader"
        principal_id                     = "00000000-0000-0000-0000-000000000004"
        skip_service_principal_aad_check = true
      }
      explicit = {
        role_definition_id_or_name       = "Reader"
        principal_id                     = "00000000-0000-0000-0000-000000000005"
        skip_service_principal_aad_check = true
        principal_type                   = "Group"
      }
      default = {
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-000000000006"
      }
    }
  }

  assert {
    condition     = azapi_resource.role_assignments["skip"].body.properties.principalType == "ServicePrincipal"
    error_message = "skip_service_principal_aad_check = true must send principalType ServicePrincipal when principal_type is unset."
  }

  assert {
    condition     = azapi_resource.role_assignments["explicit"].body.properties.principalType == "Group"
    error_message = "An explicit principal_type must win over skip_service_principal_aad_check."
  }

  assert {
    condition     = azapi_resource.role_assignments["default"].body.properties.principalType == null
    error_message = "principalType must stay unset when neither the flag nor principal_type is set."
  }

  assert {
    condition     = azapi_resource.role_assignments_rulesets["2"].body.properties.principalType == "ServicePrincipal"
    error_message = "The forwarding ruleset assignment must also send principalType ServicePrincipal when the flag is true."
  }

  assert {
    condition     = azapi_resource.role_assignments_rulesets["1"].body.properties.principalType == "Group"
    error_message = "An explicit principal_type must win on the forwarding ruleset assignment too."
  }

  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].body.properties.principalType == null
    error_message = "principalType must stay unset on the forwarding ruleset assignment when neither the flag nor principal_type is set."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "derives_distinct_lowercase_names" {
  command = apply

  variables {
    role_assignments = {
      first = {
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-00000000000A"
      }
      second = {
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-00000000000b"
      }
    }
  }

  assert {
    condition     = azapi_resource.role_assignments["first"].name != azapi_resource.role_assignments["second"].name
    error_message = "Assignments with different principals must get different derived names."
  }

  assert {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", azapi_resource.role_assignments["first"].name))
    error_message = "A derived role assignment name must be a lowercase UUIDv5."
  }

  assert {
    condition     = azapi_resource.role_assignments["first"].body.properties.principalId == "00000000-0000-0000-0000-00000000000a"
    error_message = "The principal id must be lowercased in the request body."
  }

  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name != azapi_resource.role_assignments["first"].name
    error_message = "The forwarding ruleset copy must not reuse the resolver assignment name."
  }

  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name != azapi_resource.role_assignments_rulesets["1"].name
    error_message = "Ruleset assignments with different principals must get different derived names."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "pinned_name_applies_to_the_resolver_only" {
  command = apply

  variables {
    role_assignments = {
      pinned = {
        name                       = "11111111-1111-4111-8111-111111111111"
        role_definition_id_or_name = "Reader"
        principal_id               = "00000000-0000-0000-0000-000000000004"
      }
    }
  }

  assert {
    condition     = azapi_resource.role_assignments["pinned"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "A pinned name must be used for the resolver assignment."
  }

  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name != "11111111-1111-4111-8111-111111111111"
    error_message = "A pinned name must not be reused at the forwarding ruleset scope."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "retries_principal_not_found_on_role_assignments_by_default" {
  command = apply

  assert {
    condition     = contains(azapi_resource.role_assignments["custom"].retry.error_message_regex, "PrincipalNotFound")
    error_message = "The default retry must cover PrincipalNotFound on the resolver role assignment."
  }

  assert {
    condition     = contains(azapi_resource.role_assignments_rulesets["0"].retry.error_message_regex, "PrincipalNotFound")
    error_message = "The default retry must cover PrincipalNotFound on the forwarding ruleset role assignment."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "forwards_custom_retry_to_role_assignments" {
  command = apply

  variables {
    retry = {
      error_message_regex = ["CustomTransient"]
      interval_seconds    = 7
    }
  }

  assert {
    condition     = azapi_resource.role_assignments["custom"].retry.error_message_regex == tolist(["CustomTransient"]) && azapi_resource.role_assignments["custom"].retry.interval_seconds == 7
    error_message = "A consumer retry override must reach the resolver role assignment."
  }

  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].retry.error_message_regex == tolist(["CustomTransient"])
    error_message = "A consumer retry override must reach the forwarding ruleset role assignment."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}
