<#
.SYNOPSIS
Runs offline inbound endpoint plan regressions with the real AzAPI provider.
.DESCRIPTION
Synthetic AzAPI state is built from provider-mocked Terraform test results.
Read-only data lookups are replaced with literal fixture values; the existing
mocked tests separately exercise endpoint matching and assigned-IP selection.
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
    param($Seed)
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
        '-filter=tests\unit\dynamic_ip_preservation.tftest.hcl', '-verbose', '-json'
    ) -LogName 'mocked-seeds.jsonl'
    $seeds = @{}
    foreach ($line in $events) {
        $event = $line | ConvertFrom-Json -AsHashtable -Depth 100
        if ($event.type -eq 'test_state') { $seeds[$event.'@testrun'] = $event.test_state }
    }
    if (!$seeds.ContainsKey('existing_dynamic_ip_is_preserved') -or !$seeds.ContainsKey('explicit_static_ip_is_honored')) {
        throw 'The mocked tests did not produce both required seed states.'
    }

    Copy-Item (Join-Path $modulePath '*.tf') $sandbox
    # Consumer-only provider configuration. Any accidental network request fails locally.
    @'
variable "offline_private_ip_address" {
  type    = string
  default = null
}

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

data "azapi_resource_list" "inbound_endpoints" {
  count = 0
}

locals {
  resource_group_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/rg-test"
  inbound_endpoint_private_ip_addresses = {
    dns = var.offline_private_ip_address
  }
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

    $cases = @(
        @{ Name = 'dynamic_to_static'; Seed = 'existing_dynamic_ip_is_preserved'; Method = 'Static'; IP = '10.0.4.70'; Actions = 'delete,create' }
        @{ Name = 'static_to_dynamic'; Seed = 'explicit_static_ip_is_honored'; Method = 'Dynamic'; IP = $null; Actions = 'delete,create' }
        @{ Name = 'static_address_edit'; Seed = 'explicit_static_ip_is_honored'; Method = 'Static'; IP = '10.0.4.71'; Actions = 'delete,create' }
        @{ Name = 'unchanged_adopted_dynamic'; Seed = 'existing_dynamic_ip_is_preserved'; Method = 'Dynamic'; IP = $null; Actions = 'no-op'; BodyIP = '10.0.4.68' }
        @{ Name = 'unchanged_static'; Seed = 'explicit_static_ip_is_honored'; Method = 'Static'; IP = '10.0.4.70'; Actions = 'no-op'; BodyIP = '10.0.4.70' }
        @{ Name = 'dynamic_tag_edit'; Seed = 'existing_dynamic_ip_is_preserved'; Method = 'Dynamic'; IP = $null; Actions = 'update'; BodyIP = '10.0.4.68'; Tags = @{ changed = 'true' } }
        @{ Name = 'dynamic_subnet_edit'; Seed = 'existing_dynamic_ip_is_preserved'; Method = 'Dynamic'; IP = $null; Actions = 'delete,create'; Subnet = 'different-subnet' }
        @{ Name = 'dynamic_assigned_ip_is_not_a_trigger'; Seed = 'existing_dynamic_ip_is_preserved'; Method = 'Dynamic'; IP = $null; Actions = 'update'; BodyIP = '10.0.4.69' }
    )
    $results = foreach ($case in $cases) {
        $seed = $seeds[$case.Seed] | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
        New-SyntheticState $seed | ConvertTo-Json -Depth 100 | Set-Content 'terraform.tfstate'
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
            offline_private_ip_address  = $(if ($case.ContainsKey('BodyIP')) { $case.BodyIP } else { $case.IP })
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
        if ($case.ContainsKey('BodyIP')) {
            $passed = $passed -and ($change.change.after.body.properties.ipConfigurations[0].privateIpAddress -eq $case.BodyIP)
        }
        if ($case.Name -in @('static_to_dynamic', 'dynamic_subnet_edit')) {
            $passed = $passed -and ($null -eq $change.change.after.body.properties.ipConfigurations[0].privateIpAddress)
        }
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
