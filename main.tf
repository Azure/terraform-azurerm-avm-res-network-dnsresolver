
resource "azurerm_private_dns_resolver" "this" {
  location            = local.location
  name                = var.name
  resource_group_name = var.resource_group_name
  virtual_network_id  = var.virtual_network_resource_id
  tags                = var.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "this" {
  for_each = { for key, value in var.inbound_endpoints : value.name => value }

  location                = local.location
  name                    = coalesce(each.value.name, "in-${each.key}-dnsResolver-inbound")
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  tags                    = var.tags

  ip_configurations {
    subnet_id                    = "${var.virtual_network_resource_id}/subnets/${each.value.subnet_name}"
    private_ip_address           = each.value.private_ip_address
    private_ip_allocation_method = each.value.private_ip_allocation_method
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "this" {
  for_each = { for key, value in var.outbound_endpoints : value.name => value }

  location                = local.location
  name                    = coalesce(each.value.name, "out-${each.key}-dnsResolver-outbound")
  private_dns_resolver_id = azurerm_private_dns_resolver.this.id
  subnet_id               = "${var.virtual_network_resource_id}/subnets/${each.value.subnet_name}"
  tags                    = var.tags
}


resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "this" {
  for_each = tomap({ for ruleset in local.forwarding_rulesets : "${ruleset.outbound_endpoint_name}-${ruleset.name}" => ruleset })

  location                                   = local.location
  name                                       = each.value.name
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.this[each.value.outbound_endpoint_name].id]
  resource_group_name                        = var.resource_group_name
  tags                                       = var.tags
}

resource "azurerm_private_dns_resolver_forwarding_rule" "this" {
  for_each = { for rule in local.forwarding_rules : "${rule.outbound_endpoint_name}-${rule.ruleset_name}-${rule.rule_name}" => rule }

  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this["${each.value.outbound_endpoint_name}-${each.value.ruleset_name}"].id
  domain_name               = each.value.domain_name
  name                      = each.value.rule_name
  enabled                   = each.value.enabled
  metadata                  = each.value.metadata

  dynamic "target_dns_servers" {
    for_each = each.value.destination_ip_addresses
    content {
      ip_address = target_dns_servers.key
      port       = target_dns_servers.value
    }
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "deafult" {
  for_each = tomap({ for ruleset in local.forwarding_rulesets : "${ruleset.outbound_endpoint_name}-${ruleset.name}" => ruleset if ruleset.link_with_outbound_endpoint_virtual_network == true })

  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this[each.key].id
  name                      = "deafult-${each.value.name}"
  virtual_network_id        = var.virtual_network_resource_id
}

resource "azurerm_private_dns_resolver_virtual_network_link" "additional" {
  for_each = tomap({ for link in local.forwarding_rules_vnet_links : "${link.outbound_endpoint_name}-${link.ruleset_name}-${link.vnet_key}" => link })

  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this["${each.value.outbound_endpoint_name}-${each.value.ruleset_name}"].id
  name                      = "additional-${each.value.outbound_endpoint_name}-${each.value.ruleset_name}-${substr(md5(each.value.vnet_id), 0, 6)}"
  virtual_network_id        = each.value.vnet_id
  metadata                  = each.value.metadata
}

# required AVM resources interfaces
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_private_dns_resolver.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_management_lock" "rulesets" {
  for_each = { for key, ruleset in azurerm_private_dns_resolver_dns_forwarding_ruleset.this : key => ruleset if var.lock != null }

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${each.key}")
  scope      = each.value.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "dnsresolver" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_private_dns_resolver.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}


resource "azurerm_role_assignment" "rulesets" {
  for_each = {
    for composite_key, assignment in flatten(local.ruleset_role_assignments) :
    composite_key => assignment
  }

  principal_id                           = each.value.role_assignment.principal_id
  scope                                  = each.value.ruleset_id
  condition                              = each.value.role_assignment.condition
  condition_version                      = each.value.role_assignment.condition_version
  delegated_managed_identity_resource_id = each.value.role_assignment.delegated_managed_identity_resource_id
  description                            = each.value.role_assignment.description
  role_definition_name                   = each.value.role_assignment.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.role_assignment.skip_service_principal_aad_check
}
