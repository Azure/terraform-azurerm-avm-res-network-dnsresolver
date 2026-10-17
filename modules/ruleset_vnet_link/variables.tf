variable "dns_forwarding_ruleset_id" {
  type        = string
  description = "The ID of the DNS forwarding ruleset to link to the virtual networks."

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/dnsForwardingRulesets", var.dns_forwarding_ruleset_id))
    error_message = "dns_forwarding_ruleset_id must be a valid DNS forwarding ruleset resource ID."
  }
}

variable "location" {
  type        = string
  description = "The Azure region for this module's resources or telemetry deployment."
  nullable    = false
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

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}
