##############################
# Author: David Yair [E030331]
#
# Description:
#   This script removes a specified DNS server address from a selected network interface on a Windows machine.
#   It allows the user to select the interface manually or automatically via parameters.
#   The script validates the change after DNS removal.
##############################

param (
    [Parameter(Mandatory = $true)]
    [string]$DnsAddr,

    [string]$Interface,
    [switch]$ShowHidden,
    [switch]$AutoConfirm
)

$ErrorActionPreference = 'Stop'  # Fail on all errors

$thisScriptDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$classesFile   = Join-Path $thisScriptDir "classes.ps1"
Write-Host "Loading classes from $classesFile" -ForegroundColor Yellow
. $classesFile

# Gather network adapters
Write-Host "Getting all network interfaces..."
if ($ShowHidden) {
    Write-Host "Including hidden interfaces" -ForegroundColor Yellow
}
Write-Host ""

[array]$netAdapters = if ($ShowHidden) {
    Get-NetAdapter -IncludeHidden | Where-Object { $_.Status -eq 'Up' }
} else {
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
}

if ($netAdapters.Count -eq 0) {
    Write-Host "Error - No network adapters found." -ForegroundColor Red
    if (! $ShowHidden) {
        Write-Host "Try running with -ShowHidden to include hidden adapters." -ForegroundColor Yellow
    }
    exit 1
}

# Build interface objects
$interfacesList = @()
foreach ($adapter in $netAdapters) {
    $netConProfile = Get-NetConnectionProfile -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
    $nameToAdd = if ($netConProfile.Name) { $netConProfile.Name } else { $netConProfile.InterfaceAlias }
    $nicObj = [NetworkInterface]::new($adapter.Name, $adapter.InterfaceDescription, $nameToAdd)
    $interfacesList += $nicObj
}

# Print interface options
for ($i = 0; $i -lt $interfacesList.Count; $i++) {
    $nic = $interfacesList[$i]
    Write-Host "  $($i + 1)) " -NoNewLine
    Write-Host "$($nic.Name)" -ForegroundColor Cyan -NoNewLine
    Write-Host " - $($nic.ConnectionProfileName) - $($nic.Description)" -ForegroundColor Magenta
}

# Add abort option if more than one
if ($interfacesList.Count -gt 1) {
    $abortOption = $interfacesList.Count + 1
    Write-Host "  $abortOption) Abort script" -ForegroundColor Red
}
Write-Host ""

# Select interface
if ($interfacesList.Count -gt 1) {
    Write-Host "Multiple network interfaces found. Please choose one to configure:" -ForegroundColor Yellow
    Write-Host ""

    $validChoice = $false

    if ($Interface) {
        if ($Interface -match '^\d+$') {
            $index = [int]$Interface - 1
            if ($index -ge 0 -and $index -lt $interfacesList.Count) {
                $interfaceToConfigure = $interfacesList[$index]
                Write-Host "Auto-selected interface by index: $($interfaceToConfigure.Name) - $($interfaceToConfigure.ConnectionProfileName) - $($interfaceToConfigure.Description)" -ForegroundColor Green
                $validChoice = $true
            }
        } else {
            $matched = $interfacesList | Where-Object { $_.Name -like "${Interface}*" }
            if ($matched.Count -eq 1) {
                $interfaceToConfigure = $matched
                Write-Host "Auto-selected interface by name match: $($interfaceToConfigure.Name) - $($interfaceToConfigure.ConnectionProfileName) - $($interfaceToConfigure.Description)" -ForegroundColor Green
                $validChoice = $true
            } elseif ($matched.Count -gt 1) {
                Write-Host "Warning: Multiple matches found for '$Interface', please choose manually." -ForegroundColor Yellow
            }
        }

        if (! $validChoice) {
            Write-Host "Could not find interface name or index by provided param: '$Interface'" -NoNewline
            Write-Host "Please choose manually" -ForegroundColor Yellow
            Write-Host ""
        }
    }

    while (-not $validChoice) {
        $abortIndex = $interfacesList.Count + 1
        $choice = Read-Host "Enter the number of the interface you want to configure ($abortIndex to abort)"

        if ($choice -match '^\d+$') {
            $choiceInt = [int]$choice

            if ($choiceInt -eq $abortIndex) {
                Write-Host "User aborted interface selection." -ForegroundColor Red
                exit 0
            }

            if ($choiceInt -ge 1 -and $choiceInt -le $interfacesList.Count) {
                $index = $choiceInt - 1
                $interfaceToConfigure = $interfacesList[$index]
                Write-Host "You chose: $($interfaceToConfigure.Name) - $($interfaceToConfigure.ConnectionProfileName) - $($interfaceToConfigure.Description)" -ForegroundColor Green
                $validChoice = $true
            } else {
                Write-Host "Invalid choice. Please enter a number between 1 and $($interfacesList.Count), or $abortIndex to abort." -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid input. Please enter a numeric value." -ForegroundColor Red
        }
    }
} else {
    Write-Host "OK - Only one network interface found. Using it.."
    $interfaceToConfigure = $interfacesList[0]
}

# Check current DNS servers
Write-Host ""
Write-Host "Checking current DNS servers for: $($interfaceToConfigure.Name)" -ForegroundColor Yellow
$currentDns = (Get-DnsClientServerAddress -InterfaceAlias $interfaceToConfigure.Name -AddressFamily IPv4).ServerAddresses

Write-Host "Current DNS servers:" -ForegroundColor Cyan
$currentDns | ForEach-Object { Write-Host " * $_" }

if (-not ($currentDns -contains $DnsAddr)) {
    Write-Host "DNS address '$DnsAddr' not found. Nothing to remove." -ForegroundColor Green
    exit 0
}

# Confirm removal
Write-Warning "DNS address '$DnsAddr' will be removed from interface '$($interfaceToConfigure.Name)'"
if (! $AutoConfirm) {
    CHOICE /C YN /M "Are you sure you want to remove it?"
    if ($LASTEXITCODE -eq 2) {
        Write-Host "User cancelled - aborting." -ForegroundColor Red
        exit 0
    }
} else {
    Write-Host "Auto-confirmation enabled. Proceeding..." -ForegroundColor Yellow
}

# Remove and apply
$newDnsList = $currentDns | Where-Object { $_ -ne $DnsAddr }
Write-Host "Updating DNS servers to: $($newDnsList -join ', ')" -ForegroundColor Yellow

Set-DnsClientServerAddress -InterfaceAlias $interfaceToConfigure.Name -ServerAddresses $newDnsList
if (! $?) {
    Write-Host "Error: Failed to update DNS servers." -ForegroundColor Red
    exit 1
}

# Validate removal
$finalDns = (Get-DnsClientServerAddress -InterfaceAlias $interfaceToConfigure.Name -AddressFamily IPv4).ServerAddresses
if ($finalDns -contains $DnsAddr) {
    Write-Host "Error: DNS server '$DnsAddr' still present after update." -ForegroundColor Red
    exit 1
}

Write-Host "DNS server '$DnsAddr' successfully removed from interface '$($interfaceToConfigure.Name)'." -ForegroundColor Green
