##############################
# Author: David Yair [E030331]
# 
# Description:
#   This script configures DNS settings for a selected network interface on a Windows machine.
#   It adds a new DNS server address (11.0.118.6) to the beginning of the list of existing DNS servers.
#   The script ensures the user selects the correct network interface and confirms the changes before proceeding.
#   It also validates the DNS configuration after making the changes.
##############################

param (
    [Parameter(Mandatory = $true)]
    [string]$DnsAddr,

    [string]$DnsSuffix,
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
    $nameToAdd = if($netConProfile.Name) {
        $netConProfile.Name
    } else {
        $netConProfile.InterfaceAlias
    }
    $nicObj = [NetworkInterface]::new($adapter.Name, $adapter.InterfaceDescription, $nameToAdd)
    $interfacesList += $nicObj
}

# Select interface
$interfaceToConfigure = getTargetInterface -interfacesList $interfacesList -Interface $Interface -AutoConfirm:$AutoConfirm

Write-Host "Using network interface: $($interfaceToConfigure.Name)" -ForegroundColor Green

Write-Host "Checking for DNS configuration of: $DnsAddr"
Write-Host ""

# Get the current IPv4 configuration ($interfaceToConfigure is the interface to add DNS addr to)
$ipv4Config = Get-NetIPConfiguration -InterfaceAlias $interfaceToConfigure.Name
Write-Host "Current IPv4 Configuration:" -ForegroundColor Yellow
$ipv4Config | Format-List

$existingDnsServers = printDnsServersForInterface -InterfaceName $interfaceToConfigure.Name -HighlightDns $DnsAddr

# Check if the DNS server already exists
if ($existingDnsServers -contains $DnsAddr) {
    Write-Host ""
    Write-Host "Found dns: '$DnsAddr' already configured" -ForegroundColor Green
    Write-Host "OK"
    Write-Host ""
    exit 0
}

Write-Warning "Missing DNS address '${DnsAddr}'"
Write-Host ""
Write-Host "Adding DNS server: $DnsAddr  to interface: $($interfaceToConfigure.Name)"
Write-Host ""

if (! $AutoConfirm) {
    CHOICE /C YN /M "Are you sure"
    if ($LASTEXITCODE -eq 2) {
        Write-Host "User cancelled - aborting.."
        exit 0
    }
} else {
    Write-Host "Auto-confirmation enabled. Proceeding with the changes."
}

Write-Host "OK - continuing.."
Write-Host ""

# Add the new DNS server address to the beginning of the list
$newDnsServers = @("$DnsAddr") + $existingDnsServers

# Update DNS server addresses
Write-Host "Adding new DNS server address: ${DnsAddr}..." -ForegroundColor Yellow
Set-DnsClientServerAddress -InterfaceAlias $interfaceToConfigure.Name -ServerAddresses $newDnsServers
if (! $?) {
    Write-Host "Error: Failed to add new DNS server address." -ForegroundColor Red
    exit
}

# Set DNS suffixes
if ($DnsSuffix) {
    Write-Host "Setting DNS suffix to '$DnsSuffix'..." -ForegroundColor Yellow
    Set-DnsClient -InterfaceAlias $interfaceToConfigure.Name -ConnectionSpecificSuffix $DnsSuffix
    if (! $?) {
        Write-Host "Error: Failed to set DNS suffix." -ForegroundColor Red
        exit
    }
}


# Enable "Register this connection's addresses in DNS"
Write-Host "Enabling 'Register this connection's addresses in DNS'..." -ForegroundColor Yellow
Set-DnsClient -InterfaceAlias $interfaceToConfigure.Name -RegisterThisConnectionsAddress $true
if (! $?) {
    Write-Host "Error: Failed to enable 'Register this connection's addresses in DNS'." -ForegroundColor Red
    exit
}

# Validate the connection settings
Write-Host "Validating the DNS configuration..." -ForegroundColor Yellow
$updatedConfig     = Get-DnsClient -InterfaceAlias $interfaceToConfigure.Name
$currentDnsServers = (Get-DnsClientServerAddress -InterfaceAlias $interfaceToConfigure.Name -AddressFamily IPv4).ServerAddresses
$currentDnsSuffix  = $updatedConfig.ConnectionSpecificSuffix
$registerAddresses = $updatedConfig.RegisterThisConnectionsAddress

# Check if settings match expected values
$dnsCheck      = ($currentDnsServers -contains $DnsAddr)
$suffixCheck   = ($currentDnsSuffix -eq $dnsSuffix)
$registerCheck = $registerAddresses -eq $true

if (-not $dnsCheck) {
	Write-Host "Error: DNS server address is incorrect. Expected: ${DnsAddr}, Found: $($dnsServers -join ', ')" -ForegroundColor Red
    exit
}

if ($DnsSuffix) {
    if (-not $suffixCheck) {
        Write-Host "Error: DNS suffix is incorrect. Expected: 'esl.corp.elbit.co.il', Found: '$dnsSuffix'" -ForegroundColor Red
        exit
    }
}

if (-not $registerCheck) {
    Write-Host "Error: 'Register this connection's addresses in DNS' is not enabled." -ForegroundColor Red
    exit
}

Write-Host "DNS configuration successfully updated and validated!" -ForegroundColor Green