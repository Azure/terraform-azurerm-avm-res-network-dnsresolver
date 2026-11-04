locals {
  parsed_id    = provider::azapi::parse_resource_id("Microsoft.Network/dnsForwardingRulesets", var.dns_forwarding_ruleset_id)
  ruleset_name = local.parsed_id["name"]
}

locals {
  timeouts = {
    create = coalesce(try(var.timeouts.create, null), "30m")
    delete = coalesce(try(var.timeouts.delete, null), "30m")
    read   = coalesce(try(var.timeouts.read, null), "5m")
    update = coalesce(try(var.timeouts.update, null), "30m")
  }
}
