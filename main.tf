module "interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.9.0"

  location                         = var.location
  enable_telemetry                 = var.enable_telemetry
  lock                             = var.lock
  role_assignment_definition_scope = var.parent_id
  role_assignments                 = var.role_assignments
}

resource "azapi_resource" "this" {
  location  = local.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.network_dns_resolvers
  body = {
    properties = {
      virtualNetwork = {
        id = var.virtual_network_resource_id
      }
    }
  }
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_resolvers) > 0 ? var.ignore_body_changes.network_dns_resolvers : null
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.virtualNetwork.id",
  ]
  response_export_values = [
    "properties.dnsResolverState",
    "properties.provisioningState",
  ]
  retry = var.retry
  tags  = var.tags

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
          privateIpAddress          = each.value.private_ip_address
          privateIpAllocationMethod = each.value.private_ip_allocation_method
        }
      ]
    }
  }
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_resolvers_inbound_endpoints) > 0 ? var.ignore_body_changes.network_dns_resolvers_inbound_endpoints : null
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.ipConfigurations[0].subnet.id",
    "properties.ipConfigurations[0].privateIpAllocationMethod",
    "properties.ipConfigurations[?privateIpAllocationMethod == 'Static'].privateIpAddress",
  ]
  response_export_values = [
    "properties.ipConfigurations",
    "properties.provisioningState",
  ]
  retry = var.retry
  tags  = local.inbound_endpoint_tags[each.key]

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
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_resolvers_outbound_endpoints) > 0 ? var.ignore_body_changes.network_dns_resolvers_outbound_endpoints : null
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.subnet.id",
  ]
  response_export_values = [
    "properties.provisioningState",
    "properties.subnet.id",
  ]
  retry = var.retry
  tags  = local.outbound_endpoint_tags[each.key]

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
  parent_id = var.parent_id
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
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_forwarding_rulesets) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets : null
  ignore_null_property = true
  response_export_values = [
    "properties.dnsResolverOutboundEndpoints",
    "properties.provisioningState",
  ]
  retry = var.retry
  tags  = local.forwarding_ruleset_tags[each.key]

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
      domainName          = each.value.domain_name
      forwardingRuleState = each.value.enabled ? "Enabled" : "Disabled"
      metadata            = each.value.metadata
      targetDnsServers = [
        for ip_address, port in each.value.destination_ip_addresses : {
          ipAddress = ip_address
          port      = tonumber(port)
        }
      ]
    }
  }
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_forwarding_rulesets_forwarding_rules) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets_forwarding_rules : null
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.domainName",
  ]
  response_export_values = []
  retry                  = var.retry

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
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links : null
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.virtualNetwork.id",
  ]
  response_export_values = []
  retry                  = var.retry

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
  ignore_body_changes  = length(var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links : null
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.virtualNetwork.id",
  ]
  response_export_values = []
  retry                  = var.retry

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
  type                   = var.resource_types.authorization_locks
  body                   = local.lock_body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  ignore_null_property   = true
  response_export_values = []
  retry                  = var.retry

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
  type                   = var.resource_types.authorization_locks
  body                   = local.lock_body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  ignore_null_property   = true
  response_export_values = []
  retry                  = var.retry

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

  name = coalesce(
    var.role_assignments[each.key].name,
    uuidv5("url", join("|", [
      lower(azapi_resource.this.id),
      local.role_assignment_properties[each.key].principalId,
      local.role_assignment_properties[each.key].roleDefinitionId,
      lower(coalesce(local.role_assignment_properties[each.key].delegatedManagedIdentityResourceId, "-")),
    ]))
  )
  parent_id = azapi_resource.this.id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = local.role_assignment_properties[each.key]
  }
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_casing        = true
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.delegatedManagedIdentityResourceId",
  ]
  response_export_values = []
  retry                  = var.retry

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
    ignore_changes = [name]
  }
}

resource "azapi_resource" "role_assignments_rulesets" {
  for_each = local.ruleset_role_assignments_map

  name = uuidv5("url", join("|", [
    lower(each.value.ruleset_id),
    local.role_assignment_properties[each.value.role_assignment_key].principalId,
    local.role_assignment_properties[each.value.role_assignment_key].roleDefinitionId,
    lower(coalesce(local.role_assignment_properties[each.value.role_assignment_key].delegatedManagedIdentityResourceId, "-")),
  ]))
  parent_id = each.value.ruleset_id
  type      = var.resource_types.authorization_role_assignments
  body = {
    properties = local.role_assignment_properties[each.value.role_assignment_key]
  }
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_casing        = true
  ignore_null_property = true
  replace_triggers_refs = [
    "properties.principalId",
    "properties.roleDefinitionId",
    "properties.delegatedManagedIdentityResourceId",
  ]
  response_export_values = []
  retry                  = var.retry

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
    ignore_changes = [name]
  }
}

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
