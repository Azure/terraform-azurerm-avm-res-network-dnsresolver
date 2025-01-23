
locals {
  parsed_id    = provider::azurerm::parse_resource_id(var.dns_forwarding_ruleset_id)
  ruleset_name = local.parsed_id["resource_name"]
}