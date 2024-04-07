
locals {
  location                           = var.location != null ? var.location : data.azurerm_resource_group.parent[0].location
  resource_group_location            = try(data.azurerm_resource_group.parent[0].location, null)
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}