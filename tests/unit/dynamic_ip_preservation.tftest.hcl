mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000001"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        value = [{
          name = "in-dns-dnsResolver-inbound"
          properties = {
            ipConfigurations = [{
              privateIpAddress          = "10.0.4.68"
              privateIpAllocationMethod = "Dynamic"
              subnet = {
                id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/dns"
              }
            }]
          }
        }]
      }
    }
  }
}
mock_provider "modtm" {}
mock_provider "random" {}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/resolver-test"
  }
}

variables {
  name                        = "resolver-test"
  resource_group_name         = "rg-test"
  location                    = "eastus"
  virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
  enable_telemetry            = false
  inbound_endpoints = {
    dns = { subnet_name = "dns" }
  }
}

run "existing_dynamic_ip_is_preserved" {
  command = apply

  assert {
    condition     = azapi_resource.inbound_endpoint["dns"].body.properties.ipConfigurations[0].privateIpAddress == "10.0.4.68"
    error_message = "An existing Dynamic endpoint must retain its assigned IP in the update body."
  }
}

run "fresh_dynamic_endpoint_leaves_ip_unset" {
  command = apply

  override_data {
    target = data.azapi_resource_list.inbound_endpoints[0]
    values = { output = { value = [] } }
  }

  assert {
    condition     = azapi_resource.inbound_endpoint["dns"].body.properties.ipConfigurations[0].privateIpAddress == null
    error_message = "A new Dynamic endpoint must let Azure assign its IP."
  }
}

run "explicit_static_ip_is_honored" {
  command = apply

  variables {
    inbound_endpoints = {
      dns = {
        subnet_name                  = "dns"
        private_ip_allocation_method = "Static"
        private_ip_address           = "10.0.4.70"
      }
    }
  }

  assert {
    condition     = azapi_resource.inbound_endpoint["dns"].body.properties.ipConfigurations[0].privateIpAddress == "10.0.4.70"
    error_message = "An explicit Static IP must override the previously assigned Dynamic IP."
  }
}

run "changed_subnet_does_not_reuse_old_dynamic_ip" {
  command = apply

  variables {
    inbound_endpoints = {
      dns = { subnet_name = "different-subnet" }
    }
  }

  assert {
    condition     = azapi_resource.inbound_endpoint["dns"].body.properties.ipConfigurations[0].privateIpAddress == null
    error_message = "An IP from another subnet must not be copied into a new endpoint."
  }
}

run "changed_endpoint_name_does_not_reuse_another_ip" {
  command = apply

  variables {
    inbound_endpoints = {
      dns = { name = "different-endpoint", subnet_name = "dns" }
    }
  }

  assert {
    condition     = azapi_resource.inbound_endpoint["dns"].body.properties.ipConfigurations[0].privateIpAddress == null
    error_message = "An IP belonging to another endpoint name must not be reused."
  }
}

run "switching_from_static_to_dynamic_leaves_ip_unset" {
  command = apply

  override_data {
    target = data.azapi_resource_list.inbound_endpoints[0]
    values = {
      output = {
        value = [{
          name = "in-dns-dnsResolver-inbound"
          properties = {
            ipConfigurations = [{
              privateIpAddress          = "10.0.4.70"
              privateIpAllocationMethod = "Static"
              subnet = {
                id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/dns"
              }
            }]
          }
        }]
      }
    }
  }

  assert {
    condition     = azapi_resource.inbound_endpoint["dns"].body.properties.ipConfigurations[0].privateIpAddress == null
    error_message = "Switching to Dynamic allocation must not retain a previously Static IP."
  }
}
