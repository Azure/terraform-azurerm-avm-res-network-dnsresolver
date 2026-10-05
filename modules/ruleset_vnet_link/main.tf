resource "azapi_resource" "this" {
  for_each = var.virtual_networks

  name      = "${local.ruleset_name}-${substr(md5(each.value.vnet_id), 0, 6)}"
  parent_id = var.dns_forwarding_ruleset_id
  type      = var.resource_types.network_dns_forwarding_rulesets_virtual_network_links
  body = {
    properties = {
      metadata = each.value.metadata
      virtualNetwork = {
        id = each.value.vnet_id
      }
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links : null
  # Matches AzureRM's nil-pointer/omitempty serialisation: an optional the consumer left unset
  # is absent from the request rather than sent as an explicit JSON null.
  ignore_null_property = true
  # `virtual_network_id` was ForceNew on
  # `azurerm_private_dns_resolver_virtual_network_link` (L62).
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

# =============================================================================
# AzureRM -> AzAPI state moves (`avm-tf-migration` SKILL.md L66-78)
#
# This submodule is its own `moved` boundary. The `for_each` boundary and the
# keys (`var.virtual_networks`) are unchanged, so this is a whole-resource move.
# =============================================================================

moved {
  from = azurerm_private_dns_resolver_virtual_network_link.this
  to   = azapi_resource.this
}
