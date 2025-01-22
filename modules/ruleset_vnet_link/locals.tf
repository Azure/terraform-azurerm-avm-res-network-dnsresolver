
locals {
  ruleset_name = provider::azurerm::parse_resource_id(var.dns_forwarding_ruleset_id)
}
