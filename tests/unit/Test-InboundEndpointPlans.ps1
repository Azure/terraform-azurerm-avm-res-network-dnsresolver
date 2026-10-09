<#
.SYNOPSIS
Runs offline inbound endpoint plan regressions with the real AzAPI provider.
.DESCRIPTION
Synthetic AzAPI state is built from provider-mocked Terraform test results.
The client-config lookup is replaced with literal fixture values. Adopted and
refreshed state shapes are synthesized explicitly by each case.
Only init, mocked tests, show and refresh-disabled plans run. Azure endpoints
and authentication are directed to an unused loopback port. These checks do
not prove cross-provider state moves, ARM update semantics or live convergence.
#>
[CmdletBinding()]
param(
    [string] $EvidencePath = (Join-Path ([System.IO.Path]::GetTempPath()) "dns-plan-evidence-$([guid]::NewGuid())")
)

$ErrorActionPreference = 'Stop'
$modulePath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) "dns-plan-regression-$([guid]::NewGuid())"
$null = New-Item -ItemType Directory -Path $EvidencePath, $sandbox
$EvidencePath = (Resolve-Path $EvidencePath).Path

function Invoke-Terraform {
    param([string[]] $Arguments, [string] $LogName)
    $result = & terraform @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $result | Set-Content (Join-Path $EvidencePath $LogName)
    if ($exitCode -ne 0) {
        throw "terraform $($Arguments -join ' ') exited $exitCode. See $(Join-Path $EvidencePath $LogName)."
    }
    return $result
}

function Get-DynamicType {
    param($Value)
    if ($null -eq $Value) { return 'dynamic' }
    if ($Value -is [bool]) { return 'bool' }
    if ($Value -is [string]) { return 'string' }
    if ($Value -is [System.Collections.IDictionary]) {
        $fields = @{}
        foreach ($key in $Value.Keys) { $fields[$key] = Get-DynamicType $Value[$key] }
        return ,@('object', $fields)
    }
    if ($Value -is [array]) {
        $elements = @()
        foreach ($element in $Value) { $elements += ,(Get-DynamicType $element) }
        return ,@('tuple', $elements)
    }
    return 'number'
}

function New-SyntheticState {
    param($Seed, [hashtable] $Case)
    $resources = foreach ($resource in ($Seed.root_module.resources | Where-Object mode -eq managed)) {
        $schema = $Seed.provider_schemas[$resource.provider_name]
        $block = $schema.resource_schemas[$resource.type].block
        $attributes = $resource.values
        # Mocked apply does not run AzAPI's default plan modifiers.
        if ($resource.type -eq 'azapi_resource') {
            $attributes.ignore_missing_property = $true
            $attributes.schema_validation_enabled = $true
        }
        if ($null -ne $attributes.retry) {
            $attributes.retry.interval_seconds = 10
            $attributes.retry.max_interval_seconds = 180
            $attributes.retry.multiplier = 1.5
            $attributes.retry.randomization_factor = 0.5
        }
        if ($resource.type -eq 'azapi_resource' -and $resource.name -eq 'inbound_endpoint') {
            $attributes.id = "$($attributes.parent_id)/inboundEndpoints/$($attributes.name)"
            $configuration = $attributes.body.properties.ipConfigurations[0]
            if ($Case.ContainsKey('StateBodyIP')) { $configuration.privateIpAddress = $Case.StateBodyIP }
            # Refreshed AzAPI state keeps the request body shape and exports the assigned IP.
            $attributes.output = @{
                properties = @{
                    ipConfigurations = @(@{
                        privateIpAddress          = $(if ($Case.ContainsKey('RemoteIP')) { $Case.RemoteIP } else { $configuration.privateIpAddress })
                        privateIpAllocationMethod = $configuration.privateIpAllocationMethod
                        subnet                    = @{ id = $configuration.subnet.id }
                    })
                    provisioningState = 'Succeeded'
                }
            }
        }
        foreach ($key in @($attributes.Keys)) {
            if ($block.attributes[$key].type -eq 'dynamic' -and $null -ne $attributes[$key]) {
                $attributes[$key] = @{
                    value = $attributes[$key]
                    type  = Get-DynamicType $attributes[$key]
                }
            }
        }
        $instance = @{
            schema_version = $resource.schema_version
            attributes     = $attributes
            sensitive_attributes = @()
        }
        if ($resource.Contains('index')) { $instance.index_key = $resource.index }
        @{
            mode      = $resource.mode
            type      = $resource.type
            name      = $resource.name
            provider  = "provider[`"$($resource.provider_name)`"]"
            instances = @($instance)
        }
    }
    return @{
        version           = 4
        terraform_version = (& terraform version -json | ConvertFrom-Json).terraform_version
        serial            = 1
        lineage           = [guid]::NewGuid().ToString()
        outputs           = @{}
        resources         = @($resources)
    }
}

$originalLocation = Get-Location
try {
    Set-Location $modulePath
    $events = Invoke-Terraform -Arguments @(
        'test', '-test-directory=tests\unit',
        '-filter=tests\unit\inbound_endpoint_ip.tftest.hcl', '-verbose', '-json'
    ) -LogName 'mocked-seeds.jsonl'
    $seeds = @{}
    foreach ($line in $events) {
        $event = $line | ConvertFrom-Json -AsHashtable -Depth 100
        if ($event.type -eq 'test_state') { $seeds[$event.'@testrun'] = $event.test_state }
    }
    if (!$seeds.ContainsKey('dynamic_endpoint_leaves_ip_unset') -or !$seeds.ContainsKey('explicit_static_ip_is_honored')) {
        throw 'The mocked tests did not produce both required seed states.'
    }

    Copy-Item (Join-Path $modulePath '*.tf') $sandbox
    # Consumer-only provider configuration. Any accidental network request fails locally.
    @'
provider "azapi" {
  subscription_id            = "00000000-0000-0000-0000-000000000001"
  tenant_id                  = "00000000-0000-0000-0000-000000000002"
  client_id                  = "00000000-0000-0000-0000-000000000003"
  client_secret              = "offline-test-placeholder"
  use_cli                    = false
  use_msi                    = false
  use_oidc                   = false
  use_aks_workload_identity  = false
  skip_provider_registration = true
  enable_preflight           = false
  ignore_no_op_changes       = false
  disable_instance_discovery = true
  endpoint = [{
    active_directory_authority_host = "https://127.0.0.1:1"
    resource_manager_endpoint       = "https://127.0.0.1:1"
    resource_manager_audience       = "https://127.0.0.1:1"
  }]
}
'@ | Set-Content (Join-Path $sandbox 'offline-provider.tf')
    @'
data "azapi_client_config" "current" {
  count = 0
}

locals {
  resource_group_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test"
}

module "interfaces" {
  role_assignment_definition_scope = "/subscriptions/00000000-0000-0000-0000-000000000001"
}
'@ | Set-Content (Join-Path $sandbox 'reads_override.tf')
    if (Test-Path (Join-Path $modulePath '.terraform.lock.hcl')) {
        Copy-Item (Join-Path $modulePath '.terraform.lock.hcl') $sandbox
    }
    Set-Location $sandbox
    $null = Invoke-Terraform -Arguments @('init', '-backend=false', '-input=false', '-no-color') -LogName 'init.log'

    # StateBodyIP set: adopted state, whose body is read back from Azure and includes the assigned IP.
    # StateBodyIP null: state written by this module's own create, whose body has no Dynamic IP.
    # ignore_no_op_changes is disabled, so these plans show raw body differences without a GET.
    $cases = @(
        @{ Name = 'dynamic_to_static'; Seed = 'dynamic_endpoint_leaves_ip_unset'; Method = 'Static'; IP = '10.0.4.70'; Actions = 'delete,create'; StateBodyIP = '10.0.4.68'; AfterIP = '10.0.4.70' }
        @{ Name = 'static_to_dynamic'; Seed = 'explicit_static_ip_is_honored'; Method = 'Dynamic'; IP = $null; Actions = 'delete,create'; AfterIP = $null }
        @{ Name = 'static_address_edit'; Seed = 'explicit_static_ip_is_honored'; Method = 'Static'; IP = '10.0.4.71'; Actions = 'delete,create'; AfterIP = '10.0.4.71' }
        @{ Name = 'unchanged_static'; Seed = 'explicit_static_ip_is_honored'; Method = 'Static'; IP = '10.0.4.70'; Actions = 'no-op'; AfterIP = '10.0.4.70' }
        @{ Name = 'dynamic_subnet_edit'; Seed = 'dynamic_endpoint_leaves_ip_unset'; Method = 'Dynamic'; IP = $null; Actions = 'delete,create'; Subnet = 'different-subnet'; AfterIP = $null }
        # Live regression: create leaves the body IP null, then the next plan sees the Azure-assigned IP.
        @{ Name = 'fresh_dynamic_create_then_refresh'; Seed = 'dynamic_endpoint_leaves_ip_unset'; Method = 'Dynamic'; IP = $null; Actions = 'no-op'; StateBodyIP = $null; RemoteIP = '10.0.4.68'; AfterIP = $null }
        @{ Name = 'fresh_dynamic_tag_edit'; Seed = 'dynamic_endpoint_leaves_ip_unset'; Method = 'Dynamic'; IP = $null; Actions = 'update'; StateBodyIP = $null; RemoteIP = '10.0.4.68'; Tags = @{ changed = 'true' }; AfterIP = $null }
        # Adoption drops the read-back IP with an in-place update; the assigned IP is never a replacement trigger.
        @{ Name = 'adopted_dynamic_is_not_replaced'; Seed = 'dynamic_endpoint_leaves_ip_unset'; Method = 'Dynamic'; IP = $null; Actions = 'update'; StateBodyIP = '10.0.4.68'; AfterIP = $null }
    )
    $results = foreach ($case in $cases) {
        $seed = $seeds[$case.Seed] | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
        New-SyntheticState $seed $case | ConvertTo-Json -Depth 100 | Set-Content 'terraform.tfstate'
        $endpoint = @{
            subnet_name                  = 'dns'
            private_ip_allocation_method = $case.Method
            private_ip_address           = $case.IP
        }
        if ($case.ContainsKey('Subnet')) { $endpoint.subnet_name = $case.Subnet }
        if ($case.ContainsKey('Tags')) { $endpoint.tags = $case.Tags }
        @{
            name                        = 'resolver-test'
            resource_group_name         = 'rg-test'
            location                    = 'eastus'
            virtual_network_resource_id = '/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test'
            enable_telemetry            = $false
            inbound_endpoints           = @{ dns = $endpoint }
        } | ConvertTo-Json -Depth 100 | Set-Content 'case.tfvars.json'
        $null = Invoke-Terraform -Arguments @(
            'plan', '-refresh=false', '-input=false', '-no-color',
            '-var-file=case.tfvars.json', '-out=case.tfplan'
        ) -LogName "$($case.Name).log"
        $json = Invoke-Terraform -Arguments @('show', '-json', 'case.tfplan') -LogName "$($case.Name).json"
        $plan = $json | ConvertFrom-Json -AsHashtable -Depth 100
        $change = $plan.resource_changes | Where-Object address -eq 'azapi_resource.inbound_endpoint["dns"]'
        if ($null -eq $change) { throw "No inbound endpoint change was present in $($case.Name)." }
        $actions = $change.change.actions
        $passed = ($actions -join ',') -eq $case.Actions
        $afterIP = $change.change.after.body.properties.ipConfigurations[0].privateIpAddress
        $passed = $passed -and ($(if ($null -eq $case.AfterIP) { $null -eq $afterIP } else { $afterIP -eq $case.AfterIP }))
        [pscustomobject]@{
            Case = $case.Name
            Actions = $actions -join ','
            ExpectedActions = $case.Actions
            Passed = $passed
        }
    }
    $results | ConvertTo-Json | Set-Content (Join-Path $EvidencePath 'results.json')
    $results | Format-Table -AutoSize
    Write-Host "Evidence: $EvidencePath"
    if ($results.Passed -contains $false) { throw 'Inbound endpoint plan regressions failed.' }
} finally {
    Set-Location $originalLocation
    [Environment]::CurrentDirectory = $originalLocation.Path
    Remove-Item -LiteralPath $sandbox -Recurse -Force
}
