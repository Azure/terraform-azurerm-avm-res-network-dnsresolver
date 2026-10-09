locals {
  # TFNFR38 (Severity-MUST): parse a resource ID with a LITERAL type, never with a regex.
  # `provider::azapi::parse_resource_id` returns `name` where the AzureRM equivalent returned
  # `resource_name`.
  parsed_id    = provider::azapi::parse_resource_id("Microsoft.Network/dnsForwardingRulesets", var.dns_forwarding_ruleset_id)
  ruleset_name = local.parsed_id["name"]
}

locals {
  # `azurerm_private_dns_resolver_virtual_network_link` used create 30m / read 5m /
  # update 30m / delete 30m (azurerm v4.36.0,
  # internal/services/privatednsresolver/private_dns_resolver_virtual_network_link_resource.go).
  timeouts = {
    create = coalesce(try(var.timeouts.create, null), "30m")
    delete = coalesce(try(var.timeouts.delete, null), "30m")
    read   = coalesce(try(var.timeouts.read, null), "5m")
    update = coalesce(try(var.timeouts.update, null), "30m")
  }
}
