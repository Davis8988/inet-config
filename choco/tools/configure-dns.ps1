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
    [Parameter(Mandatory=$true)]
    [string]$DnsAddr,

    [string]$DnsSuffix,
    [string]$Interface,
    [switch]$ShowHidden,
    [switch]$AutoConfirm
)

$ErrorActionPreference = 'Stop' # stop on all errors

$thisScriptDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$classesFile   = Join-Path $thisScriptDir "classes.ps1"
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

Write-Host "Attempting to find connection profiles for each adapter:" -ForegroundColor Yellow
Write-Host ""
$interfacesList = @()
foreach ($adapter in $netAdapters) {
    $netConProfile = Get-NetConnectionProfile -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
    if (! $netConProfile) {
        Write-Warning " * No connection profile found for interface $($adapter.Name) - Cannot configure it"
        continue
    }
    $nicObj = [NetworkInterface]::new($adapter.Name, $adapter.InterfaceDescription, $netConProfile.Name)
    $interfacesList += $nicObj
}

# Print the list of network interfaces
foreach ($i in 0..($interfacesList.Count - 1)) {
    $nic = $interfacesList[$i]
    Write-Host "[$i] $($nic.ToString())" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Done"
Write-Host ""
Read-Host
exit 0

# Check if there is more than one interface
if ($interfacesList.Count -gt 1) {
    Write-Host "Multiple network interfaces found. Please choose one to configure:" -ForegroundColor Yellow
    
	Write-Host ""
    
    $validChoice = $false
    while (-not $validChoice) {
		$choice = Read-Host "Enter the number of the interface you want to configure"
		if ($choice -match '^\d+$' -and [int]$choice -ge 0 -and [int]$choice -lt $interfacesList.Count) {
			$interfaceToConfigure = $interfacesList[$choice]
			$validChoice = $true
		} else {
			Write-Host "Invalid choice. Please enter a valid number between 0 and $($interfacesList.Count - 1)." -ForegroundColor Red
		}
	}
} else {
    # Continue with the single interface
	Write-Host "Only one network interface found"
    $interfaceToConfigure = $interfacesList[0]
}

Write-Host "Using network interface: $($interfaceToConfigure.Name)" -ForegroundColor Green

Write-Host ""
Write-Host "Checking for DNS configuration of: $DnsAddr"
Write-Host ""

# Get the current IPv4 configuration ($interfaceToConfigure is the interface to add DNS addr to)
$ipv4Config = Get-NetIPConfiguration -InterfaceAlias $interfaceToConfigure.Name
Write-Host "Current IPv4 Configuration:" -ForegroundColor Yellow
$ipv4Config | Format-List

# Get existing DNS server addresses
$existingDnsServers = (Get-DnsClientServerAddress -InterfaceAlias $interfaceToConfigure.Name -AddressFamily IPv4).ServerAddresses

# Print the current configured DNS servers
Write-Host "Interface `"$($interfaceToConfigure.Name)`" Current configured DNS servers:" -ForegroundColor Yellow
foreach ($dnsServer in $existingDnsServers) {
    if ($dnsServer -eq $DnsAddr) {
		Write-Host " * " -NoNewLine ; Write-Host $dnsServer -NoNewLine -ForegroundColor Cyan ; Write-Host "  <-- Found" -ForegroundColor Magenta
	} else {
		Write-Host " * ${dnsServer}"
	}
}

# Check if the DNS server already exists
if ($existingDnsServers -contains $DnsAddr) {
    Write-Host ""
    Write-Host "Found dns: '$DnsAddr' already configured" -ForegroundColor Green
    Write-Host "OK"
    Write-Host ""
    exit 0
}

Write-Warning "Missing DNS address '${dnsToAdd}'"
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
Write-Host "Adding new DNS server address: ${dnsToAdd}..." -ForegroundColor Yellow
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
	Write-Host "Error: DNS server address is incorrect. Expected: ${dnsToAdd}, Found: $($dnsServers -join ', ')" -ForegroundColor Red
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