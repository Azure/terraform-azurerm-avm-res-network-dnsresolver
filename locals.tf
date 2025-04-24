
# Deafult locals

locals {
  # The location where the resources will be created
  location = var.location
  # The substring used to identify role definitions in Azure
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}


# The following locals create new lists from the outbound_endpoints variable
# The outbound_endpoints variable is an object that represents each outbound endpoint to be created and attached to the private DNS resolver
# as well as the forwarding rulesets, rules and virtual network links associated with each outbound endpoint
# To be able to create the resources in the correct order, the locals are used to create lists of the forwarding rulesets, rules and virtual network links

locals {
  # Creating a list of forwarding rules for each forwarding ruleset.
  # This list is itterated over in the azurerm_private_dns_resolver_forwarding_rule resource
  forwarding_rules = flatten([
    for ruleset in local.forwarding_rulesets : [
      for rule_name, rule in ruleset.ruleset.rules : {
        outbound_endpoint_name           = ruleset.outbound_endpoint_name
        additional_virtual_network_links = ruleset.ruleset.additional_virtual_network_links
        ruleset_name                     = ruleset.name
        rule_name                        = rule_name == null ? "rule-${ruleset.name}-${rule_name}" : rule_name
        domain_name                      = rule.domain_name
        enabled                          = rule.enabled
        metadata                         = rule.metadata
        destination_ip_addresses         = rule.destination_ip_addresses
      }
    ]
  ])
  # Creating a list of virtual network links for each forwarding ruleset.
  # This list is itterated over in the azurerm_private_dns_resolver_virtual_network_link.additional resource
  forwarding_rules_vnet_links = flatten([
    for ruleset_name, ruleset in local.forwarding_rulesets : [
      for key, vnet in ruleset.additional_virtual_network_links : {
        outbound_endpoint_name = ruleset.outbound_endpoint_name
        ruleset_name           = ruleset.name
        vnet_id                = vnet.vnet_id
        metadata               = vnet.metadata
        name                   = vnet.name
        vnet_key               = key
      }
    ]
  ])
  # Creating a list of forwarding rulesets for each outbound endpoint. skipping outbound endpoints without forwarding rulesets
  # This list is itterated over in the azurerm_private_dns_resolver_dns_forwarding_ruleset resource
  forwarding_rulesets = flatten([
    for ob_ep_key, outbound_endpoint in var.outbound_endpoints : [
      for ruleset_key, ruleset in outbound_endpoint.forwarding_ruleset : {
        outbound_endpoint_name                         = ob_ep_key
        name                                           = ruleset.name == null ? "ruleset-${ob_ep_key}-${ruleset_key}" : ruleset.name
        link_with_outbound_endpoint_virtual_network    = ruleset.link_with_outbound_endpoint_virtual_network
        metadata_for_outbound_endpoint_virtual_network = ruleset.metadata_for_outbound_endpoint_virtual_network_link
        additional_virtual_network_links               = ruleset.additional_virtual_network_links
        ruleset                                        = ruleset
      }
    ] if outbound_endpoint.forwarding_ruleset != null
  ])
  # Creating a list of role assignments for each forwarding ruleset.
  # This list is itterated over in the azurerm_role_assignment.rulesets resource
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