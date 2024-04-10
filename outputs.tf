# Module owners should include the full resource via a 'resource' output
# https://azure.github.io/Azure-Verified-Modules/specs/terraform/#id-tffr2---category-outputs---additional-terraform-outputs

output "inbound_endpoint_ips" {
  description = "The IP addresses of the inbound endpoints."
  value       = { for idx, endpoint in azurerm_private_dns_resolver_inbound_endpoint.this : idx => endpoint.ip_configurations[0].private_ip_address }
}

output "name" {
  description = "The name of the DNS resolver."
  value       = azurerm_private_dns_resolver.this.name
}

output "resource" {
  description = "This is the full output for the resource."
  value       = azurerm_private_dns_resolver.this
}

output "resource_id" {
  description = "The ID of the DNS resolver."
  value       = azurerm_private_dns_resolver.this.id
}