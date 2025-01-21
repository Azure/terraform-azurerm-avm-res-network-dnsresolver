output "forwarding_rulesets" {
  description = "The forwarding rulesets of the DNS resolver."
  value       = azurerm_private_dns_resolver_dns_forwarding_ruleset.this
}

output "inbound_endpoint_ips" {
  description = "The IP addresses of the inbound endpoints."
  value       = { for idx, endpoint in azurerm_private_dns_resolver_inbound_endpoint.this : idx => endpoint.ip_configurations[0].private_ip_address }
}

output "inbound_endpoints" {
  description = "The inbound endpoints of the DNS resolver."
  value       = azurerm_private_dns_resolver_inbound_endpoint.this
}

output "name" {
  description = "The name of the DNS resolver."
  value       = azurerm_private_dns_resolver.this.name
}

output "outbound_endpoints" {
  description = "The outbound endpoints of the DNS resolver."
  value       = azurerm_private_dns_resolver_outbound_endpoint.this
}

output "resource" {
  description = "This is the full output for the resource."
  value       = azurerm_private_dns_resolver.this
}

output "resource_id" {
  description = "The ID of the DNS resolver."
  value       = azurerm_private_dns_resolver.this.id
}
