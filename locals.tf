
locals {
  resource_group_location            = try(data.azurerm_resource_group.parent[0].location, null)
  location                          = var.location != null ? var.location : data.azurerm_resource_group.parent[0].location
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}