locals {
  location = var.location
}

locals {
  timeouts = {
    create = coalesce(try(var.timeouts.create, null), "30m")
    delete = coalesce(try(var.timeouts.delete, null), "30m")
    read   = coalesce(try(var.timeouts.read, null), "5m")
    update = coalesce(try(var.timeouts.update, null), "30m")
  }
}

locals {
  role_assignment_properties = {
    for key, assignment in module.interfaces.role_assignments_azapi : key => merge(
      assignment.body.properties,
      {
        principalId      = lower(assignment.body.properties.principalId)
        roleDefinitionId = lower(assignment.body.properties.roleDefinitionId)
      },
      assignment.body.properties.delegatedManagedIdentityResourceId == null ? {} : {
        delegatedManagedIdentityResourceId = lower(assignment.body.properties.delegatedManagedIdentityResourceId)
      },
      var.role_assignments[key].skip_service_principal_aad_check && var.role_assignments[key].principal_type == null ? {
        principalType = "ServicePrincipal"
      } : {},
    )
  }
}

locals {
  lock_body = var.lock == null ? null : {
    properties = merge(module.interfaces.lock_azapi.body.properties, {
      notes = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
    })
  }
}

locals {
  forwarding_ruleset_tags = {
    for key, ruleset in tomap({ for ruleset in local.forwarding_rulesets : "${ruleset.outbound_endpoint_name}-${ruleset.name}" => ruleset }) :
    key => ruleset.tags != null ? (ruleset.merge_with_module_tags ? merge(var.tags, ruleset.tags) : ruleset.tags) : (ruleset.merge_with_module_tags ? var.tags : {})
  }
  inbound_endpoint_tags = {
    for key, endpoint in var.inbound_endpoints :
    key => endpoint.tags != null ? (endpoint.merge_with_module_tags ? merge(var.tags, endpoint.tags) : endpoint.tags) : (endpoint.merge_with_module_tags ? var.tags : {})
  }
  outbound_endpoint_tags = {
    for key, endpoint in var.outbound_endpoints :
    key => endpoint.tags != null ? (endpoint.merge_with_module_tags ? merge(var.tags, endpoint.tags) : endpoint.tags) : (endpoint.merge_with_module_tags ? var.tags : {})
  }
}

# The following locals create new lists from the outbound_endpoints variable
# The outbound_endpoints variable is an object that represents each outbound endpoint to be created and attached to the private DNS resolver
# as well as the forwarding rulesets, rules and virtual network links associated with each outbound endpoint
# To be able to create the resources in the correct order, the locals are used to create lists of the forwarding rulesets, rules and virtual network links

locals {
  # Creating a list of forwarding rules for each forwarding ruleset.
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
  forwarding_rulesets = flatten([
    for ob_ep_key, outbound_endpoint in var.outbound_endpoints : [
      for ruleset_key, ruleset in outbound_endpoint.forwarding_ruleset : {
        outbound_endpoint_name                         = ob_ep_key
        name                                           = ruleset.name == null ? "ruleset-${ob_ep_key}-${ruleset_key}" : ruleset.name
        link_with_outbound_endpoint_virtual_network    = ruleset.link_with_outbound_endpoint_virtual_network
        metadata_for_outbound_endpoint_virtual_network = ruleset.metadata_for_outbound_endpoint_virtual_network_link
        additional_virtual_network_links               = ruleset.additional_virtual_network_links
        additional_outbound_endpoint_link              = ruleset.additional_outbound_endpoint_link
        tags                                           = ruleset.tags
        merge_with_module_tags                         = ruleset.merge_with_module_tags
        ruleset                                        = ruleset
      }
    ] if outbound_endpoint.forwarding_ruleset != null
  ])
  # Creating a list of role assignments for each forwarding ruleset.
  ruleset_role_assignments = [
    for ruleset_index, ruleset in local.forwarding_rulesets : [
      for role_assignment_key, role_assignment in var.role_assignments : {
        ruleset_id          = azapi_resource.forwarding_ruleset["${ruleset.outbound_endpoint_name}-${ruleset.name}"].id
        role_assignment     = role_assignment
        role_assignment_key = role_assignment_key
        composite_key       = "${ruleset_index}-${role_assignment_key}"
      }
    ]
  ]
  ruleset_role_assignments_map = {
    for composite_key, assignment in flatten(local.ruleset_role_assignments) :
    composite_key => assignment
  }
}
