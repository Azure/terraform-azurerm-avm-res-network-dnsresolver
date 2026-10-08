# The standard AVM interfaces (resource lock, role assignments) rendered as AzAPI bodies.
# `role_assignment_definition_scope` is the subscription, matching the scope AzureRM used when
# it resolved `role_definition_name` to a role definition id.
module "interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.6.0"

  enable_telemetry                 = var.enable_telemetry
  lock                             = var.lock
  role_assignment_definition_scope = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  role_assignments                 = var.role_assignments
}

resource "azapi_resource" "this" {
  location  = local.location
  name      = var.name
  parent_id = local.resource_group_resource_id
  type      = var.resource_types.network_dns_resolvers
  body = {
    properties = {
      virtualNetwork = {
        id = var.virtual_network_resource_id
      }
    }
  }
  create_headers      = local.azapi_headers
  delete_headers      = local.azapi_headers
  ignore_body_changes = length(var.ignore_body_changes.network_dns_resolvers) > 0 ? var.ignore_body_changes.network_dns_resolvers : null
  # Matches AzureRM's nil-pointer/omitempty serialisation: an optional the consumer left unset
  # is absent from the request rather than sent as an explicit JSON null.
  ignore_null_property = true
  read_headers         = local.azapi_headers
  # `virtual_network_id` was ForceNew on `azurerm_private_dns_resolver` (L61): a resolver
  # cannot be repointed at a different virtual network in place.
  replace_triggers_refs = [
    "properties.virtualNetwork.id",
  ]
  response_export_values = [
    "properties.dnsResolverState",
    "properties.provisioningState",
  ]
  retry          = var.retry
  tags           = var.tags
  update_headers = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "inbound_endpoint" {
  for_each = var.inbound_endpoints

  location  = local.location
  name      = coalesce(each.value.name, "in-${each.key}-dnsResolver-inbound")
  parent_id = azapi_resource.this.id
  type      = var.resource_types.network_dns_resolvers_inbound_endpoints
  body = {
    properties = {
      ipConfigurations = [
        {
          subnet = {
            id = "${var.virtual_network_resource_id}/subnets/${each.value.subnet_name}"
          }
          # Validation limits this to Static endpoints. A Dynamic IP is assigned by Azure and is
          # never read back into the body, so a refresh after create cannot introduce a diff.
          privateIpAddress          = each.value.private_ip_address
          privateIpAllocationMethod = each.value.private_ip_allocation_method
        }
      ]
    }
  }
  create_headers       = local.azapi_headers
  delete_headers       = local.azapi_headers
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_resolvers_inbound_endpoints) > 0 ? var.ignore_body_changes.network_dns_resolvers_inbound_endpoints : null
  ignore_null_property = true
  read_headers         = local.azapi_headers
  # Preserve AzureRM's IP-configuration replacement semantics without tracking assigned Dynamic IPs.
  replace_triggers_refs = [
    "properties.ipConfigurations[0].subnet.id",
    "properties.ipConfigurations[0].privateIpAllocationMethod",
    "properties.ipConfigurations[?privateIpAllocationMethod == 'Static'].privateIpAddress",
  ]
  # Refresh these exports at adoption so downstream DNS consumers receive the assigned IP.
  response_export_values = [
    "properties.ipConfigurations",
    "properties.provisioningState",
  ]
  retry          = var.retry
  tags           = local.inbound_endpoint_tags[each.key]
  update_headers = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "outbound_endpoint" {
  for_each = var.outbound_endpoints

  location  = local.location
  name      = coalesce(each.value.name, "out-${each.key}-dnsResolver-outbound")
  parent_id = azapi_resource.this.id
  type      = var.resource_types.network_dns_resolvers_outbound_endpoints
  body = {
    properties = {
      subnet = {
        id = "${var.virtual_network_resource_id}/subnets/${each.value.subnet_name}"
      }
    }
  }
  create_headers       = local.azapi_headers
  delete_headers       = local.azapi_headers
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_resolvers_outbound_endpoints) > 0 ? var.ignore_body_changes.network_dns_resolvers_outbound_endpoints : null
  ignore_null_property = true
  read_headers         = local.azapi_headers
  # `subnet_id` was ForceNew on `azurerm_private_dns_resolver_outbound_endpoint` (L66).
  replace_triggers_refs = [
    "properties.subnet.id",
  ]
  response_export_values = [
    "properties.provisioningState",
    "properties.subnet.id",
  ]
  retry          = var.retry
  tags           = local.outbound_endpoint_tags[each.key]
  update_headers = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# the "terraform_data" resource is used to trigger replacement of the forwarding rulesets when the outbound endpoint is recreated"
#
# 🔴 KEPT DELIBERATELY. Removing it would destroy live `terraform_data` state entries and
# would also broaden the trigger: `replace_triggered_by` on a single resource INSTANCE fires
# when that instance is planned for update as well as for replace, so pointing the rulesets
# straight at the endpoint would recreate them on any endpoint change (a tag edit, for
# example). `input` now holds the AzAPI id; AzAPI re-serialises the same parsed ARM id, so the
# stored value is unchanged and no ruleset is triggered at adoption.
resource "terraform_data" "outbound" {
  for_each = tomap({ for ruleset in local.forwarding_rulesets : "${ruleset.outbound_endpoint_name}-${ruleset.name}" => ruleset })

  input = azapi_resource.outbound_endpoint[each.value.outbound_endpoint_name].id
}

# Creating a private DNS resolver DNS forwarding ruleset and forwarding rules for each outbound endpoint.
# The ruleset is linked to the outbound endpoint it is created under, and can optionally link to an additional outbound endpoint provided in the "additional_outbound_endpoint_link" attribute.
resource "azapi_resource" "forwarding_ruleset" {
  for_each = tomap({ for ruleset in local.forwarding_rulesets : "${ruleset.outbound_endpoint_name}-${ruleset.name}" => ruleset })

  location  = local.location
  name      = each.value.name
  parent_id = local.resource_group_resource_id
  type      = var.resource_types.network_dns_forwarding_rulesets
  body = {
    properties = {
      dnsResolverOutboundEndpoints = [
        {
          id = azapi_resource.outbound_endpoint[each.value.outbound_endpoint_name].id
        }
      ]
    }
  }
  create_headers       = local.azapi_headers
  delete_headers       = local.azapi_headers
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_forwarding_rulesets) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets : null
  ignore_null_property = true
  read_headers         = local.azapi_headers
  # No `replace_triggers_refs`: the only ForceNew field on
  # `azurerm_private_dns_resolver_dns_forwarding_ruleset` was `name` (L50), which AzAPI already
  # treats as a replacement trigger natively. Outbound-endpoint replacement is propagated by
  # `terraform_data.outbound` below, exactly as before.
  response_export_values = [
    "properties.dnsResolverOutboundEndpoints",
    "properties.provisioningState",
  ]
  retry          = var.retry
  tags           = local.forwarding_ruleset_tags[each.key]
  update_headers = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    replace_triggered_by = [terraform_data.outbound[each.key]]
  }
}

resource "azapi_resource" "forwarding_rule" {
  for_each = { for rule in local.forwarding_rules : "${rule.outbound_endpoint_name}-${rule.ruleset_name}-${rule.rule_name}" => rule }

  name      = each.value.rule_name
  parent_id = azapi_resource.forwarding_ruleset["${each.value.outbound_endpoint_name}-${each.value.ruleset_name}"].id
  type      = var.resource_types.network_dns_forwarding_rulesets_forwarding_rules
  body = {
    properties = {
      domainName = each.value.domain_name
      # AzureRM mapped the `enabled` bool onto this enum (forwarding_rule_resource.go L136-139).
      forwardingRuleState = each.value.enabled ? "Enabled" : "Disabled"
      metadata            = each.value.metadata
      # `destination_ip_addresses` is a map(string) keyed by IP with the port as the value, but
      # ARM types `port` as an Integer, so the port is converted here. AzureRM got the same
      # conversion for free from its TypeInt schema.
      targetDnsServers = [
        for ip_address, port in each.value.destination_ip_addresses : {
          ipAddress = ip_address
          port      = tonumber(port)
        }
      ]
    }
  }
  create_headers       = local.azapi_headers
  delete_headers       = local.azapi_headers
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_forwarding_rulesets_forwarding_rules) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets_forwarding_rules : null
  ignore_null_property = true
  read_headers         = local.azapi_headers
  # `domain_name` was ForceNew on `azurerm_private_dns_resolver_forwarding_rule` (L71).
  replace_triggers_refs = [
    "properties.domainName",
  ]
  response_export_values = []
  retry                  = var.retry
  update_headers         = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "virtual_network_link_default" {
  for_each = tomap({ for ruleset in local.forwarding_rulesets : "${ruleset.outbound_endpoint_name}-${ruleset.name}" => ruleset if ruleset.link_with_outbound_endpoint_virtual_network == true })

  name      = "default-${each.value.name}"
  parent_id = azapi_resource.forwarding_ruleset[each.key].id
  type      = var.resource_types.network_dns_forwarding_rulesets_virtual_network_links
  body = {
    properties = {
      virtualNetwork = {
        id = var.virtual_network_resource_id
      }
    }
  }
  create_headers       = local.azapi_headers
  delete_headers       = local.azapi_headers
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links : null
  ignore_null_property = true
  read_headers         = local.azapi_headers
  # `virtual_network_id` was ForceNew on
  # `azurerm_private_dns_resolver_virtual_network_link` (L62).
  replace_triggers_refs = [
    "properties.virtualNetwork.id",
  ]
  response_export_values = []
  retry                  = var.retry
  update_headers         = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "virtual_network_link_additional" {
  for_each = tomap({ for link in local.forwarding_rules_vnet_links : "${link.outbound_endpoint_name}-${link.ruleset_name}-${link.vnet_key}" => link })

  name      = coalesce(each.value.name, "additional-${each.value.outbound_endpoint_name}-${each.value.ruleset_name}-${substr(md5(each.value.vnet_id), 0, 6)}")
  parent_id = azapi_resource.forwarding_ruleset["${each.value.outbound_endpoint_name}-${each.value.ruleset_name}"].id
  type      = var.resource_types.network_dns_forwarding_rulesets_virtual_network_links
  body = {
    properties = {
      metadata = each.value.metadata
      virtualNetwork = {
        id = each.value.vnet_id
      }
    }
  }
  create_headers       = local.azapi_headers
  delete_headers       = local.azapi_headers
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links : null
  ignore_null_property = true
  read_headers         = local.azapi_headers
  replace_triggers_refs = [
    "properties.virtualNetwork.id",
  ]
  response_export_values = []
  retry                  = var.retry
  update_headers         = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# required AVM resources interfaces
resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name                   = coalesce(module.interfaces.lock_azapi.name, "lock-${var.lock.kind}")
  parent_id              = azapi_resource.this.id
  type                   = module.interfaces.lock_azapi.type
  body                   = local.lock_body
  create_headers         = local.azapi_headers
  delete_headers         = local.azapi_headers
  ignore_null_property   = true
  read_headers           = local.azapi_headers
  response_export_values = []
  retry                  = var.retry
  update_headers         = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "lock_rulesets" {
  for_each = { for key, ruleset in azapi_resource.forwarding_ruleset : key => ruleset if var.lock != null }

  name                   = coalesce(module.interfaces.lock_azapi.name, "lock-${each.key}")
  parent_id              = each.value.id
  type                   = module.interfaces.lock_azapi.type
  body                   = local.lock_body
  create_headers         = local.azapi_headers
  delete_headers         = local.azapi_headers
  ignore_null_property   = true
  read_headers           = local.azapi_headers
  response_export_values = []
  retry                  = var.retry
  update_headers         = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "role_assignments" {
  for_each = module.interfaces.role_assignments_azapi

  name                   = each.value.name
  parent_id              = azapi_resource.this.id
  type                   = each.value.type
  body                   = each.value.body
  create_headers         = local.azapi_headers
  delete_headers         = local.azapi_headers
  ignore_null_property   = true
  read_headers           = local.azapi_headers
  response_export_values = []
  retry                  = var.retry
  update_headers         = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  # 🔴 REQUIRED BY THE MIGRATION, blessed by `avm-tf-migration` SKILL.md L113-117.
  # A role assignment's name is a server-assigned GUID. The state move recovers it from the
  # resource id, while `avm-utl-interfaces` would offer a freshly generated `random_uuid`, and
  # `name` carries `RequiresReplace` in AzAPI -- so without this the adoption plan would
  # DESTROY AND RECREATE every existing role assignment. `ignore_changes` is inert at create
  # time, so genuinely new role assignments still take the generated UUID.
  lifecycle {
    ignore_changes = [name]
  }
}

# One name per ruleset role assignment. `avm-utl-interfaces` only generates names for the
# top-level `var.role_assignments` keys; reusing those GUIDs at a second scope would collide,
# so the ruleset copies get their own.
resource "random_uuid" "role_assignments_rulesets" {
  for_each = local.ruleset_role_assignments_map
}

resource "azapi_resource" "role_assignments_rulesets" {
  for_each = local.ruleset_role_assignments_map

  name      = random_uuid.role_assignments_rulesets[each.key].result
  parent_id = each.value.ruleset_id
  type      = module.interfaces.role_assignments_azapi[each.value.role_assignment_key].type
  # AzureRM passed `role_definition_id_or_name` to `role_definition_name` unconditionally here,
  # which failed whenever a consumer supplied a role definition ID. The interfaces module looks
  # the name up and passes an ID straight through, so both forms now work.
  body                   = module.interfaces.role_assignments_azapi[each.value.role_assignment_key].body
  create_headers         = local.azapi_headers
  delete_headers         = local.azapi_headers
  ignore_null_property   = true
  read_headers           = local.azapi_headers
  response_export_values = []
  retry                  = var.retry
  update_headers         = local.azapi_headers

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [local.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  # See `azapi_resource.role_assignments`.
  lifecycle {
    ignore_changes = [name]
  }
}

# =============================================================================
# AzureRM -> AzAPI state moves (`avm-tf-migration` SKILL.md L66-78)
#
# The provider migration is IN PLACE: same module, same `for_each`/`count`
# boundary, same keys, so every move is a whole-resource move and the consumer
# only bumps the module version. Plan with a normal refresh: the `move_state`
# private flag makes the first refreshing read backfill `body` from Azure
# (`azapi_resource.go` L1281-1289). A `-refresh=false` plan hits azapi#1227 and
# plans a replace on every resource that carries `location`.
# =============================================================================

moved {
  from = azurerm_private_dns_resolver.this
  to   = azapi_resource.this
}

moved {
  from = azurerm_private_dns_resolver_inbound_endpoint.this
  to   = azapi_resource.inbound_endpoint
}

moved {
  from = azurerm_private_dns_resolver_outbound_endpoint.this
  to   = azapi_resource.outbound_endpoint
}

moved {
  from = azurerm_private_dns_resolver_dns_forwarding_ruleset.this
  to   = azapi_resource.forwarding_ruleset
}

moved {
  from = azurerm_private_dns_resolver_forwarding_rule.this
  to   = azapi_resource.forwarding_rule
}

moved {
  from = azurerm_private_dns_resolver_virtual_network_link.default
  to   = azapi_resource.virtual_network_link_default
}

moved {
  from = azurerm_private_dns_resolver_virtual_network_link.additional
  to   = azapi_resource.virtual_network_link_additional
}

moved {
  from = azurerm_management_lock.this[0]
  to   = azapi_resource.lock[0]
}

moved {
  from = azurerm_management_lock.rulesets
  to   = azapi_resource.lock_rulesets
}

moved {
  from = azurerm_role_assignment.dnsresolver
  to   = azapi_resource.role_assignments
}

moved {
  from = azurerm_role_assignment.rulesets
  to   = azapi_resource.role_assignments_rulesets
}
