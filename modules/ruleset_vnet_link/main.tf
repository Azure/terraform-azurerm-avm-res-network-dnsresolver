
resource "azurerm_private_dns_resolver_virtual_network_link" "this" {
  for_each = var.virtual_networks

  dns_forwarding_ruleset_id = var.dns_forwarding_ruleset_id
  name                      = "${local.ruleset_name}-${substr(md5(each.value.vnet_id), 0, 6)}"
  virtual_network_id        = each.value.vnet_id
  metadata                  = each.value.metadata
}