variable "dns_forwarding_ruleset_id" {
  type        = string
  description = "The ID of the DNS forwarding ruleset to link to the virtual networks."
}

variable "virtual_networks" {
  type = map(object({
    vnet_id = string
  metadata = optional(map(string), null) }))
  description = <<DESCRIPTION
A map virtual network links to create.
  - `vnet_id` - (Required) The ID of the virtual network to link to.
  - `metadata` - (Optional) A map of metadata to associate with the virtual network link.
DESCRIPTION
}
