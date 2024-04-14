
# Deafult locals

locals {
  location                           = var.location
  resource_group_location            = var.location
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

# Locals for outbound endpoints

locals {
  forwarding_rules = flatten([
    for ruleset in local.forwarding_rulesets : [
      for rule_name, rule in ruleset.ruleset.rules : {
        outbound_endpoint_name           = ruleset.outbound_endpoint_name
        additional_virtual_network_links = ruleset.ruleset.additional_virtual_network_links_resource_ids
        ruleset_name                     = ruleset.name
        rule_name                        = rule_name == null ? "rule-${ruleset.name}-${rule_name}" : rule_name
        domain_name                      = rule.domain_name
        state                            = rule.state
        destination_ip_addresses         = rule.destination_ip_addresses
      }
    ]
  ])
  forwarding_rules_vnet_links = flatten([
    for ruleset_name, ruleset in local.forwarding_rulesets : [
      for vnet_id in ruleset.additional_virtual_network_links_resource_ids : {
        outbound_endpoint_name = ruleset.outbound_endpoint_name
        ruleset_name           = ruleset.name
        vnet_id                = vnet_id
      }
    ]
  ])
  forwarding_rulesets = flatten([
    for ob_ep_key, outbound_endpoint in var.outbound_endpoints : [
      for ruleset_key, ruleset in outbound_endpoint.forwarding_ruleset : {
        outbound_endpoint_name                        = ob_ep_key
        name                                          = ruleset.name == null ? "ruleset-${ob_ep_key}-${ruleset_key}" : ruleset.name
        link_with_outbound_endpoint_virtual_network   = ruleset.link_with_outbound_endpoint_virtual_network
        additional_virtual_network_links_resource_ids = ruleset.additional_virtual_network_links_resource_ids
        ruleset                                       = ruleset
      }
    ] if outbound_endpoint.forwarding_ruleset != null
  ])
  ruleset_role_assignments = [
    for ruleset_index, ruleset in local.forwarding_rulesets : [
      for role_assignment_key, role_assignment in var.role_assignments : {
        ruleset_id          = azurerm_private_dns_resolver_dns_forwarding_ruleset.this["${ruleset.outbound_endpoint_name}-${ruleset.name}"].id
        role_assignment     = role_assignment
        role_assignment_key = role_assignment_key
        composite_key       = "${ruleset_index}-${role_assignment_key}"
      }
    ]
  ]
}