# terraform-azurerm-avm-res-network-dnsresolver

This is a module for deploying private dns resolver. It can be used to deploy the reosolver, inbound endpoints, outbound endpoints, forwarding rulesets and rules.


> [!IMPORTANT]
> As the overall AVM framework is not GA (generally available) yet - the CI framework and test automation is not fully functional and implemented across all supported languages yet - breaking changes are expected, and additional customer feedback is yet to be gathered and incorporated. Hence, modules **MUST NOT** be published at version `1.0.0` or higher at this time.
> 
> All module **MUST** be published as a pre-release version (e.g., `0.1.0`, `0.1.1`, `0.2.0`, etc.) until the AVM framework becomes GA.
> 
> However, it is important to note that this **DOES NOT** mean that the modules cannot be consumed and utilized. They **CAN** be leveraged in all types of environments (dev, test, prod etc.). Consumers can treat them just like any other IaC module and raise issues or feature requests against them as they learn from the usage of the module. Consumers should also read the release notes for each version, if considering updating to a more recent version of a module to see if there are any considerations or breaking changes etc.

## Features And Notes
- This module deploys a private dns resolver and optional inbound and outbound endpoints.
- It also deploys optional forwarding rulesets and rules for outbound endpoints.
- An existing virtual network with appropriately sized **empty** subnets is required.
- For information on the Azure Private DNS Resolver service, see [Private DNS Resolver](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview).
- For information on how to configure subnets for the resolver, see [Inbound Endpoints](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview#inbound-endpoints) and [Outbound Endpoints](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview#outbound-endpoints).

## Provider Migration (AzureRM to AzAPI)

This module now creates every Azure resource with the [`azapi`](https://registry.terraform.io/providers/Azure/azapi/latest) provider. The `azurerm` provider is no longer required and is no longer declared.

**What you must do when upgrading.** Remove the `azurerm` provider from the `required_providers` of any configuration that only declared it for this module, and add `Azure/azapi`. The module carries in-module `moved` blocks for every resource it owns, so the existing state is migrated automatically: run `terraform init -upgrade` and then `terraform plan`, and review the plan before applying.

> [!IMPORTANT]
> Run the upgrade plan **with refresh enabled** (the default). The state move records only the resource identity; the provider reads the rest of each resource body back from Azure during the refresh. Planning the upgrade with `-refresh=false` can produce spurious replacements.

**Expected upgrade plan.** The upgrade is designed to produce no unintended destroys or replacements. Review in-place updates before applying; they reconcile the API version recorded by the state move and populate exported response values.

For an existing Dynamic inbound endpoint, the module lists inbound endpoints before its update
and resends the assigned IP only when the endpoint name, subnet and allocation method match.
New endpoints leave the IP unset so Azure can assign it. Explicit Static IP values take
precedence. The deployment identity needs permission to list inbound endpoints on the resolver.

**Breaking changes.**

- **Outputs.** `inbound_endpoints`, `outbound_endpoints`, `forwarding_rulesets` and `resource` now return discrete objects projected from the AzAPI response body rather than the `azurerm` resource schema. Consumers that indexed into `azurerm`-specific attribute names must be updated. `inbound_endpoint_ips`, `name` and `resource_id` are unchanged.
- **`role_assignments[*].skip_service_principal_aad_check`** is accepted for compatibility but has no effect, because the underlying ARM API has no equivalent. Azure AD propagation delays are handled with `var.retry` instead.
- **Tags** are now an AzAPI `Optional`/`Computed` attribute. Leaving `var.tags` unset no longer guarantees that tags placed on the resources out of band are removed. Manage tags explicitly if you rely on this module to own them.

**New inputs.** `resource_types`, `ignore_body_changes`, `retry` and `timeouts` are new optional inputs that expose the AzAPI API version, per-resource ignored body paths, retry behaviour, and operation timeouts. All defaults preserve the previous behaviour.

## Feedback
- Your feedback is welcome! Please raise an issue or feature request on the module's GitHub repository.
