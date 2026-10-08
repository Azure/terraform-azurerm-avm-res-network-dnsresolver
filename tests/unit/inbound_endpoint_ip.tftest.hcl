mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000001"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
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

run "dynamic_endpoint_leaves_ip_unset" {
  command = apply

  assert {
    condition     = azapi_resource.inbound_endpoint["dns"].body.properties.ipConfigurations[0].privateIpAddress == null
    error_message = "A Dynamic endpoint must never send an IP, so Azure assigns it and refreshes cannot diff it."
  }
  assert {
    condition     = azapi_resource.inbound_endpoint["dns"].body.properties.ipConfigurations[0].privateIpAllocationMethod == "Dynamic"
    error_message = "The default allocation method must be Dynamic."
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
    error_message = "An explicit Static IP must be sent in the body."
  }
}

run "switching_from_static_to_dynamic_leaves_ip_unset" {
  command = apply

  assert {
    condition     = azapi_resource.inbound_endpoint["dns"].body.properties.ipConfigurations[0].privateIpAddress == null
    error_message = "Switching to Dynamic allocation must not retain a previously Static IP."
  }
}