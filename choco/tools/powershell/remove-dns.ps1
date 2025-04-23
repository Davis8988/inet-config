##############################
# Author: David Yair [E030331]
#
# Description:
#   This script removes a specified DNS server address from a selected network interface on a Windows machine.
#   It lists interfaces, allows selection (manual or automatic), removes the DNS, and validates the change.
##############################

param (
    [Parameter(Mandatory = $true)]
    [string]$DnsAddr,

    [string]$Interface,
    [switch]$ShowHidden,
    [switch]$AutoConfirm
)

$ErrorActionPreference = 'Stop' # stop on all errors

$thisScriptDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$functionsFile = Join-Path $thisScriptDir $(Join-Path "helpers" "functions.ps1")
$classesFile   = Join-Path $thisScriptDir $(Join-Path "helpers" "classes.ps1")

# Load functions and classes
Write-Host "Loading functions from $functionsFile" -ForegroundColor Yellow
. $functionsFile
Write-Host "Loading classes from $classesFile" -ForegroundColor Yellow
. $classesFile

# Get all network interfaces, including hidden ones
Write-Host "Getting all network interfaces.."
if ($ShowHidden) {
    Write-Host "Including hidden interfaces" -ForegroundColor Yellow
}
Write-Host ""

[array]$netAdapters = if ($ShowHidden) {
    Get-NetAdapter -IncludeHidden | Where-Object { $_.Status -eq 'Up' }
} else {
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
}

Write-Host "Found $($netAdapters.Count) network adapters:" -ForegroundColor Yellow
foreach ($adapter in $netAdapters) {
    Write-Host " * $($adapter.Name) - $($adapter.InterfaceDescription)" -ForegroundColor Cyan
}
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host ""

# Check if any interfaces were found
if ($netAdapters.Count -eq 0) {
    Write-Host "Error - No network adapters found." -ForegroundColor Red
    if (! $ShowHidden) {
        Write-Host "Try running with -ShowHidden to include hidden adapters." -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "Attempting to find connection profiles for each adapter:"
Write-Host ""
$interfacesList = @()
foreach ($adapter in $netAdapters) {
    $netConProfile = Get-NetConnectionProfile -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
    $nameToAdd = if ($netConProfile.Name) { $netConProfile.Name } else { $netConProfile.InterfaceAlias }
    $nicObj = [NetworkInterface]::new($adapter.Name, $adapter.InterfaceDescription, $nameToAdd)
    $interfacesList += $nicObj
}

# Select interface
$interfaceToConfigure = getTargetInterface -interfacesList $interfacesList -Interface $Interface -AutoConfirm:$AutoConfirm
Write-Host "Using network interface: $($interfaceToConfigure.Name)" -ForegroundColor Green

# Get current DNS config
Write-Host "Checking current DNS servers for: $($interfaceToConfigure.Name)"
$existingDnsServers = getDnsServersForInterface -InterfaceName $interfaceToConfigure.Name
printDnsServersForInterface -InterfaceName $interfaceToConfigure.Name -DnsServers $existingDnsServers -HighlightDns $DnsAddr

# Check if target DNS exists
if (-not ($existingDnsServers -contains $DnsAddr)) {
    Write-Host ""
    Write-Host "DNS address '$DnsAddr' not found on interface. Nothing to remove." -ForegroundColor Green
    exit 0
}

# Confirm removal
Write-Warning "DNS address '$DnsAddr' will be removed from interface '$($interfaceToConfigure.Name)'"
Write-Host ""
if (! $AutoConfirm) {
    CHOICE /C YN /M "Are you sure you want to remove it?"
    if ($LASTEXITCODE -eq 2) {
        Write-Host "User cancelled - aborting." -ForegroundColor Red
        exit 0
    }
} else {
    Write-Host "Auto-confirmation enabled. Proceeding with removal." -ForegroundColor Yellow
}

# Remove the DNS address
$newDnsList = $existingDnsServers | Where-Object { $_ -ne $DnsAddr }
Write-Host "Updating DNS server list to: $($newDnsList -join ', ')" -ForegroundColor Yellow
Set-DnsClientServerAddress -InterfaceAlias $interfaceToConfigure.Name -ServerAddresses $newDnsList

if (! $?) {
    Write-Host "Error: Failed to update DNS servers." -ForegroundColor Red
    exit 1
}

# Validate result
Write-Host "Validating updated DNS server list..." -ForegroundColor Yellow
$finalDns = getDnsServersForInterface -InterfaceName $interfaceToConfigure.Name
printDnsServersForInterface -InterfaceName $interfaceToConfigure.Name -DnsServers $finalDns -HighlightDns $DnsAddr

if ($finalDns -contains $DnsAddr) {
    Write-Host "Error: DNS server '$DnsAddr' is still present after update." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "DNS server '$DnsAddr' successfully removed from interface '$($interfaceToConfigure.Name)'." -ForegroundColor Green
