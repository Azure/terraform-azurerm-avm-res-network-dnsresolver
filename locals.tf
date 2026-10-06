# Deafult locals

locals {
  # Request headers carrying the AVM telemetry User-Agent, applied to every `azapi_resource`
  # in this module. `null` when telemetry is disabled so no header is sent at all.
  azapi_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  # The location where the resources will be created
  location = var.location
  # The resource group that hosts the DNS resolver and the forwarding rulesets. AzAPI addresses
  # a resource by its parent scope rather than by a `resource_group_name` argument.
  resource_group_resource_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
}

locals {
  # Per-resource timeout fallbacks. Every resource this module replaced -- the six
  # `azurerm_private_dns_resolver*` resources plus `azurerm_management_lock` and
  # `azurerm_role_assignment` -- used the same defaults, so one set covers the module:
  # create 30m / read 5m / update 30m / delete 30m
  # (azurerm v4.36.0, internal/services/privatednsresolver/*_resource.go).
  timeouts = {
    create = coalesce(try(var.timeouts.create, null), "30m")
    delete = coalesce(try(var.timeouts.delete, null), "30m")
    read   = coalesce(try(var.timeouts.read, null), "5m")
    update = coalesce(try(var.timeouts.update, null), "30m")
  }
}

locals {
  # `avm-utl-interfaces` builds the lock body without `notes`. The AzureRM resources this
  # module replaced always set `notes`, so it is merged back in to avoid a day-2 diff.
  lock_body = var.lock == null ? null : {
    properties = merge(module.interfaces.lock_azapi.body.properties, {
      notes = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
    })
  }
}

locals {
  # AzureRM updates resend the assigned Dynamic IP. Preserve it only for the same endpoint and subnet.
  inbound_endpoint_private_ip_addresses = {
    for key, endpoint in var.inbound_endpoints : key => (
      endpoint.private_ip_address != null || endpoint.private_ip_allocation_method != "Dynamic"
      ? endpoint.private_ip_address
      : one(flatten([
        for existing in data.azapi_resource_list.inbound_endpoints[0].output.value : [
          for configuration in existing.properties.ipConfigurations : configuration.privateIpAddress
          if configuration.privateIpAllocationMethod == "Dynamic" &&
          lower(configuration.subnet.id) == lower("${var.virtual_network_resource_id}/subnets/${endpoint.subnet_name}")
        ]
        if lower(existing.name) == lower(coalesce(endpoint.name, "in-${key}-dnsResolver-inbound"))
      ]))
    )
  }

  # Tag resolution for the child resources, lifted out of `main.tf` unchanged so the
  # merge-with-module-tags behaviour is identical to the AzureRM implementation.
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
  # This list is itterated over in the azapi_resource.forwarding_rule resource
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
  # This list is itterated over in the azapi_resource.virtual_network_link_additional resource
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
  # This list is itterated over in the azapi_resource.forwarding_ruleset resource
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
  # This list is itterated over in the azapi_resource.role_assignments_rulesets resource
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
  # 🔴 KEY SHAPE -- DO NOT "FIX" THIS.
  # `ruleset_role_assignments` is a list OF LISTS, so after `flatten()` the iteration
  # variable `composite_key` is the numeric LIST INDEX as a string ("0", "1", ...), not the
  # `composite_key` FIELD inside each object. Live state created by
  # `azurerm_role_assignment.rulesets` is keyed exactly that way, and the `moved` block at the
  # bottom of `main.tf` is a whole-resource move, so the keys must stay byte-for-byte
  # identical. Keying this map on `assignment.composite_key` instead would silently plan a
  # destroy + create of every ruleset role assignment.
  ruleset_role_assignments_map = {
    for composite_key, assignment in flatten(local.ruleset_role_assignments) :
    composite_key => assignment
  }
}
