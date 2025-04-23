##############################
# Author: David Yair [E030331]
# 
# Description:
#   This script removes a specified DNS server address from a selected network interface on a Windows machine.
#   It lists all available interfaces and allows the user to select one.
#   After removal, it validates the result.
##############################

param (
    [Parameter(Mandatory = $true)]
    [string]$DnsAddr,

    [string]$Interface,
    [switch]$ShowHidden,
    [switch]$AutoConfirm
)

$ErrorActionPreference = 'Stop' # Stop on all errors

$thisScriptDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
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

if ($netAdapters.Count -eq 0) {
    Write-Host "Error - No network adapters found." -ForegroundColor Red
    if (! $ShowHidden) {
        Write-Host "Try running with -ShowHidden to include hidden adapters." -ForegroundColor Yellow
    }
    exit 1
}

$interfacesList = @()
foreach ($adapter in $netAdapters) {
    $profile = Get-NetConnectionProfile -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
    $profileName = if ($profile.Name) { $profile.Name } else { $adapter.Name }
    $nic = [NetworkInterface]::new($adapter.Name, $adapter.InterfaceDescription, $profileName)
    $interfacesList += $nic
}

# Select interface if needed
if ($interfacesList.Count -gt 1 -and ! $Interface) {
    Write-Host "Multiple interfaces found. Please choose one:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $interfacesList.Count; $i++) {
        $nic = $interfacesList[$i]
        Write-Host "$($i + 1)) " -NoNewLine
        Write-Host "$($nic.Name)" -ForegroundColor Cyan -NoNewLine
        Write-Host " - $($nic.ConnectionProfileName) - $($nic.Description)" -ForegroundColor Magenta
    }

    $validChoice = $false
    while (-not $validChoice) {
        $choice = Read-Host "Enter the number of the interface you want to use"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $interfacesList.Count) {
            $interfaceToUse = $interfacesList[[int]$choice - 1]
            $validChoice = $true
        } else {
            Write-Host "Invalid choice. Enter a number between 1 and $($interfacesList.Count)" -ForegroundColor Red
        }
    }
} elseif ($Interface) {
    $interfaceToUse = $interfacesList | Where-Object { $_.Name -eq $Interface }
    if (! $interfaceToUse) {
        Write-Host "Error: Interface '$Interface' not found." -ForegroundColor Red
        exit 1
    }
} else {
    $interfaceToUse = $interfacesList[0]
    Write-Host "Only one interface found. Using: $($interfaceToUse.Name)" -ForegroundColor Green
}

Write-Host "Checking DNS servers for interface: $($interfaceToUse.Name)" -ForegroundColor Green
$currentDns = (Get-DnsClientServerAddress -InterfaceAlias $interfaceToUse.Name -AddressFamily IPv4).ServerAddresses

if (-not ($currentDns -contains $DnsAddr)) {
    Write-Host "DNS address '$DnsAddr' not found in current configuration." -ForegroundColor Yellow
    exit 0
}

Write-Host "DNS address '$DnsAddr' will be removed." -ForegroundColor Yellow

if (! $AutoConfirm) {
    CHOICE /C YN /M "Are you sure you want to remove it?"
    if ($LASTEXITCODE -eq 2) {
        Write-Host "User cancelled - aborting." -ForegroundColor Red
        exit 0
    }
} else {
    Write-Host "Auto-confirmation enabled. Proceeding..." -ForegroundColor Yellow
}

$newDnsList = $currentDns | Where-Object { $_ -ne $DnsAddr }

Write-Host "Updating DNS servers to: $($newDnsList -join ', ')" -ForegroundColor Yellow
Set-DnsClientServerAddress -InterfaceAlias $interfaceToUse.Name -ServerAddresses $newDnsList
if (! $?) {
    Write-Host "Error: Failed to update DNS servers." -ForegroundColor Red
    exit 1
}

# Re-check to confirm
$finalDns = (Get-DnsClientServerAddress -InterfaceAlias $interfaceToUse.Name -AddressFamily IPv4).ServerAddresses
if ($finalDns -contains $DnsAddr) {
    Write-Host "Error: DNS server '$DnsAddr' still present after update." -ForegroundColor Red
    exit 1
}

Write-Host "DNS server '$DnsAddr' successfully removed from interface '$($interfaceToUse.Name)'." -ForegroundColor Green
