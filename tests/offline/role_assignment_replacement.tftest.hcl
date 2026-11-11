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


provider "azapi" {
  alias                      = "offline"
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  tenant_id                  = "00000000-0000-0000-0000-000000000001"
  client_id                  = "00000000-0000-0000-0000-000000000002"
  client_secret              = "not-a-real-secret"
  use_cli                    = false
  use_msi                    = false
  use_oidc                   = false
  use_aks_workload_identity  = false
  skip_provider_registration = true
  enable_preflight           = false
  ignore_no_op_changes       = false
  disable_instance_discovery = true
  endpoint = [{
    active_directory_authority_host = "https://127.0.0.1:1/"
    resource_manager_endpoint       = "https://127.0.0.1:1/"
    resource_manager_audience       = "https://127.0.0.1:1/"
  }]
}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/resolver-review"
  }
}

override_resource {
  target = azapi_resource.outbound_endpoint
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/resolver-review/outboundEndpoints/out-review"
  }
}

override_resource {
  target = azapi_resource.forwarding_ruleset
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsForwardingRulesets/ruleset-review"
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
  enable_telemetry            = false
  name                        = "resolver-review"
  location                    = "eastus"
  parent_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
  outbound_endpoints = {
    out = {
      name        = "out-review"
      subnet_name = "outbound"
      forwarding_ruleset = {
        review = {
          name  = "ruleset-review"
          rules = {}
        }
      }
    }
  }
  role_assignments = {
    reader = {
      name                       = "11111111-1111-4111-8111-111111111111"
      principal_id               = "22222222-2222-4222-8222-222222222222"
      role_definition_id_or_name = "Reader"
    }
  }
}

run "seed_existing_assignment" {
  command = apply
  providers = {
    azapi  = azapi
    random = random
  }
  assert {
    condition = azapi_resource.role_assignments_rulesets["0"].name == uuidv5("url", join("|", [
      lower(azapi_resource.forwarding_ruleset["out-ruleset-review"].id),
      "22222222-2222-4222-8222-222222222222",
      "/subscriptions/00000000-0000-0000-0000-000000000000/providers/microsoft.authorization/roledefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7",
      "-",
    ])) && azapi_resource.role_assignments_rulesets["0"].name == "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "The seed ruleset assignment name must be the derived name that the plan runs compare against."
  }
}

run "real_provider_preserves_existing_guids" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "An existing resolver assignment must retain its GUID when the module derives a different name."
  }
  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name == "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "An existing ruleset assignment keeps its GUID when nothing changes."
  }
}

run "real_provider_replaces_principal_edit_with_fresh_guids" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      reader = {
        principal_id               = "33333333-3333-4333-8333-333333333333"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name != "11111111-1111-4111-8111-111111111111" && azapi_resource.role_assignments["reader"].body.properties.principalId == "33333333-3333-4333-8333-333333333333"
    error_message = "A principal edit must replace the resolver assignment with a new GUID, not reuse the adopted one."
  }
  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name != "bb083112-57bf-5b1b-a271-8bb54ef7bd1b" && azapi_resource.role_assignments_rulesets["0"].body.properties.principalId == "33333333-3333-4333-8333-333333333333"
    error_message = "A principal edit must replace the ruleset assignment with a new GUID, not reuse the adopted one."
  }
}

run "real_provider_replaces_role_edit_with_fresh_guids" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name != "11111111-1111-4111-8111-111111111111" && endswith(azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId, "b24988ac-6180-42a0-ab88-20f7382dd24c")
    error_message = "A role edit must replace the resolver assignment with a new GUID, not reuse the adopted one."
  }
  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name != "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "A role edit must replace the ruleset assignment with a new GUID, not reuse the adopted one."
  }
}

run "real_provider_replaces_delegated_identity_edit_with_fresh_guids" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      reader = {
        principal_id                           = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name             = "Reader"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name != "11111111-1111-4111-8111-111111111111"
    error_message = "A delegated-identity edit must replace the resolver assignment with a new GUID, not reuse the adopted one."
  }
  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name != "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "A delegated-identity edit must replace the ruleset assignment with a new GUID, not reuse the adopted one."
  }
}

run "real_provider_replaces_immutable_and_mutable_edit_with_fresh_guids" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      reader = {
        principal_id               = "33333333-3333-4333-8333-333333333333"
        role_definition_id_or_name = "Reader"
        description                = "A mutable edit must not hide the immutable one."
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name != "11111111-1111-4111-8111-111111111111" && azapi_resource.role_assignments["reader"].body.properties.description == "A mutable edit must not hide the immutable one."
    error_message = "An immutable edit together with a mutable edit must still replace the resolver assignment with a new GUID."
  }
  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name != "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "An immutable edit together with a mutable edit must still replace the ruleset assignment with a new GUID."
  }
}

run "real_provider_allows_description_edit" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
        description                = "Updated description"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.description == "Updated description" && azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "Mutable changes must remain allowed without changing the resolver assignment GUID."
  }
  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name == "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "Mutable changes must remain allowed without changing the ruleset assignment GUID."
  }
}

run "real_provider_allows_condition_edit" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
        condition                  = "(!(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write'}))"
        condition_version          = "2.0"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.conditionVersion == "2.0" && azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "Mutable condition changes must keep the resolver assignment GUID."
  }
  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name == "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "Mutable condition changes must keep the ruleset assignment GUID."
  }
}

run "real_provider_keeps_guids_when_skip_check_adds_principal_type" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      reader = {
        principal_id                     = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name       = "Reader"
        skip_service_principal_aad_check = true
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.principalType == "ServicePrincipal" && azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111"
    error_message = "Adding the skip flag must send principalType without replacing the resolver assignment."
  }
  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].body.properties.principalType == "ServicePrincipal" && azapi_resource.role_assignments_rulesets["0"].name == "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "Adding the skip flag must send principalType without replacing the ruleset assignment."
  }
}

run "real_provider_accepts_equivalent_role_id_casing" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      reader = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/MICROSOFT.AUTHORIZATION/roleDefinitions/ACDD72A7-3385-48EF-BD42-F606FBA81AE7"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name == "11111111-1111-4111-8111-111111111111" && azapi_resource.role_assignments_rulesets["0"].name == "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "A change in casing alone must not replace either assignment."
  }
}

run "remove_old_assignment" {
  command = apply
  providers = {
    azapi  = azapi
    random = random
  }
  variables {
    role_assignments = {}
  }
}

run "recreate_with_new_principal_and_guids" {
  command = apply
  providers = {
    azapi  = azapi
    random = random
  }
  variables {
    role_assignments = {
      reader = {
        principal_id               = "33333333-3333-4333-8333-333333333333"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].name != "11111111-1111-4111-8111-111111111111" && azapi_resource.role_assignments["reader"].body.properties.principalId == "33333333-3333-4333-8333-333333333333"
    error_message = "Removal and recreation must allow a new principal with a fresh resolver GUID."
  }
  assert {
    condition     = azapi_resource.role_assignments_rulesets["0"].name != "bb083112-57bf-5b1b-a271-8bb54ef7bd1b"
    error_message = "Removal and recreation must allow a new principal with a fresh ruleset GUID."
  }
}

run "seed_delegated_identity" {
  command = apply
  providers = {
    azapi  = azapi
    random = random
  }
  variables {
    role_assignments = {
      delegated = {
        principal_id                           = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name             = "Reader"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
      }
    }
  }
}

run "real_provider_replaces_delegated_identity_removal_with_fresh_guids" {
  command = plan
  providers = {
    azapi  = azapi.offline
    random = random
  }
  plan_options {
    refresh = false
  }
  variables {
    role_assignments = {
      delegated = {
        principal_id               = "22222222-2222-4222-8222-222222222222"
        role_definition_id_or_name = "Reader"
      }
    }
  }
  assert {
    condition = azapi_resource.role_assignments["delegated"].name == uuidv5("url", join("|", [
      lower(azapi_resource.this.id),
      "22222222-2222-4222-8222-222222222222",
      "/subscriptions/00000000-0000-0000-0000-000000000000/providers/microsoft.authorization/roledefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7",
      "-",
    ]))
    error_message = "Removing a delegated identity must replace the resolver assignment with the newly derived GUID."
  }
  assert {
    condition = azapi_resource.role_assignments_rulesets["0"].name == uuidv5("url", join("|", [
      lower(azapi_resource.forwarding_ruleset["out-ruleset-review"].id),
      "22222222-2222-4222-8222-222222222222",
      "/subscriptions/00000000-0000-0000-0000-000000000000/providers/microsoft.authorization/roledefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7",
      "-",
      ])) && azapi_resource.role_assignments_rulesets["0"].name != uuidv5("url", join("|", [
      lower(azapi_resource.forwarding_ruleset["out-ruleset-review"].id),
      "22222222-2222-4222-8222-222222222222",
      "/subscriptions/00000000-0000-0000-0000-000000000000/providers/microsoft.authorization/roledefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7",
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/rg-test/providers/microsoft.managedidentity/userassignedidentities/delegated",
    ]))
    error_message = "Removing a delegated identity must replace the ruleset assignment with a new GUID."
  }
}
