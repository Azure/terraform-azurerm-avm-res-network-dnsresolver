# Azure Private DNS Resolver Ruleset VNet Link Module

This is a module for linking existing vnets to an existing forwarding ruleset in an Azure Private DNS Resolver outbound endpoint.


## Features And Notes
This module is used to link existing vnets to an existing forwarding ruleset in an Azure Private DNS Resolver outbound endpoint. It is usefull when you want to decouple the dns resolver resources from the linking of vnets to the forwarding ruleset. it supports:
- linking a single vnet to a single forwarding ruleset

## Provider Migration (AzureRM to AzAPI)

This module now creates its virtual network links with the [`azapi`](https://registry.terraform.io/providers/Azure/azapi/latest) provider. The `azurerm` provider is no longer required and is no longer declared.

An in-module `moved` block migrates the existing state automatically. Run `terraform init -upgrade` and then `terraform plan` **with refresh enabled** (the default), and review the plan before applying. The upgrade is designed to produce no destroys and no replacements; an in-place update on the migrated links is expected. Link names are unchanged.

`resource_types`, `ignore_body_changes`, `retry` and `timeouts` are new optional inputs. All defaults preserve the previous behaviour.

## Upgrade notes

Direct Terraform Registry or Git callers of `//modules/ruleset_vnet_link` must provide `location` with a region valid for their cloud. Telemetry is enabled by default; set `enable_telemetry = false` to opt out. When enabled, telemetry requires `Microsoft.Resources/deployments/read`, `Microsoft.Resources/deployments/write`, and `Microsoft.Resources/deployments/delete` at the active subscription scope. Root-module telemetry forwarding does not supply these required inputs for standalone child callers.

## Feedback
- Your feedback is welcome! Please raise an issue or feature request on the module's GitHub repository.
