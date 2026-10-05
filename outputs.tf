# Outputs are DISCRETE objects assembled from the `azapi_resource` attributes and from
# `response_export_values`, not the whole provider resource object. This is a BREAKING change
# for consumers who read AzureRM-only attributes off these outputs.


output "forwarding_rulesets" {
  description = "The forwarding rulesets of the DNS resolver, keyed by `\"<outbound endpoint key>-<ruleset name>\"`."
  value = {
    for key, ruleset in azapi_resource.forwarding_ruleset : key => {
      id                  = ruleset.id
      name                = ruleset.name
      location            = ruleset.location
      resource_group_name = var.resource_group_name
      tags                = ruleset.tags
      # Field name kept as AzureRM's `azurerm_private_dns_resolver_dns_forwarding_ruleset`
      # spelled it: an in-place migration must not change the module's public interface.
      private_dns_resolver_outbound_endpoint_ids = try([for endpoint in ruleset.output.properties.dnsResolverOutboundEndpoints : endpoint.id], null)
      provisioning_state                         = try(ruleset.output.properties.provisioningState, null)
    }
  }
}

output "inbound_endpoint_ips" {
  description = "The IP addresses of the inbound endpoints."
  value       = { for key, endpoint in azapi_resource.inbound_endpoint : key => try(endpoint.output.properties.ipConfigurations[0].privateIpAddress, null) }
}

output "inbound_endpoints" {
  description = "The inbound endpoints of the DNS resolver."
  value = {
    for key, endpoint in azapi_resource.inbound_endpoint : key => {
      id                           = endpoint.id
      name                         = endpoint.name
      location                     = endpoint.location
      private_dns_resolver_id      = endpoint.parent_id
      tags                         = endpoint.tags
      subnet_id                    = try(endpoint.output.properties.ipConfigurations[0].subnet.id, null)
      private_ip_address           = try(endpoint.output.properties.ipConfigurations[0].privateIpAddress, null)
      private_ip_allocation_method = try(endpoint.output.properties.ipConfigurations[0].privateIpAllocationMethod, null)
      provisioning_state           = try(endpoint.output.properties.provisioningState, null)
    }
  }
}

output "name" {
  description = "The name of the DNS resolver."
  value       = azapi_resource.this.name
}

output "outbound_endpoints" {
  description = "The outbound endpoints of the DNS resolver."
  value = {
    for key, endpoint in azapi_resource.outbound_endpoint : key => {
      id                      = endpoint.id
      name                    = endpoint.name
      location                = endpoint.location
      private_dns_resolver_id = endpoint.parent_id
      tags                    = endpoint.tags
      subnet_id               = try(endpoint.output.properties.subnet.id, null)
      provisioning_state      = try(endpoint.output.properties.provisioningState, null)
    }
  }
}

output "resource" {
  description = "This is the full output for the resource."
  value = {
    id                  = azapi_resource.this.id
    name                = azapi_resource.this.name
    location            = azapi_resource.this.location
    resource_group_name = var.resource_group_name
    tags                = azapi_resource.this.tags
    # Field name kept as AzureRM's `azurerm_private_dns_resolver` spelled it (`virtual_network_id`),
    # even though the module's own input variable is `virtual_network_resource_id`: an in-place
    # migration must not change the module's public interface.
    virtual_network_id = var.virtual_network_resource_id
    dns_resolver_state = try(azapi_resource.this.output.properties.dnsResolverState, null)
    provisioning_state = try(azapi_resource.this.output.properties.provisioningState, null)
  }
}

output "resource_id" {
  description = "The ID of the DNS resolver."
  value       = azapi_resource.this.id
}
