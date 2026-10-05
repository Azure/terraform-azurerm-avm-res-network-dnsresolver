output "resource_id" {
  description = <<DESCRIPTION
Usage: To get the id of the link, use the same keys you used in the `virtual_networks` map.
module.<module_name>.resource_id["<vnet_key>"]
DESCRIPTION
  value = {
    for vnet_key, vnet_resource in azapi_resource.this :
    vnet_key => vnet_resource.id
  }
}
