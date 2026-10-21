output "vnet2_link_resource_id" {
  description = "The resource ID of the direct child-module link for vnet2."
  value       = module.ruleset_vnet_link.resource_id["vnet2"]
}
