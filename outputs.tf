output "forwarding_rulesets" {
  description = "Discrete forwarding ruleset objects, keyed by `\"<outbound endpoint key>-<ruleset name>\"`, rather than complete provider resource objects."
  value = {
    for key, ruleset in azapi_resource.forwarding_ruleset : key => {
      id                                         = ruleset.id
      name                                       = ruleset.name
      location                                   = ruleset.location
      resource_group_name                        = var.resource_group_name
      tags                                       = ruleset.tags
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
  description = "Discrete inbound endpoint objects, keyed by endpoint key, with subnet_id, private_ip_address and private_ip_allocation_method at the object level instead of a nested ip_configurations block."
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
  description = "Discrete outbound endpoint objects, keyed by endpoint key, rather than complete provider resource objects."
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
  description = "A discrete DNS resolver object containing id, name, location, resource_group_name, tags, virtual_network_id and exported state fields, rather than the complete provider resource object."
  value = {
    id                  = azapi_resource.this.id
    name                = azapi_resource.this.name
    location            = azapi_resource.this.location
    resource_group_name = var.resource_group_name
    tags                = azapi_resource.this.tags
    virtual_network_id  = var.virtual_network_resource_id
    dns_resolver_state  = try(azapi_resource.this.output.properties.dnsResolverState, null)
    provisioning_state  = try(azapi_resource.this.output.properties.provisioningState, null)
  }
}

output "resource_id" {
  description = "The ID of the DNS resolver."
  value       = azapi_resource.this.id
}
