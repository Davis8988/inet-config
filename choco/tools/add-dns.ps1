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

Write-Host "Attempting to find connection profiles for each adapter:"
Write-Host ""
$interfacesList = @()
foreach ($adapter in $netAdapters) {
    $netConProfile = Get-NetConnectionProfile -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
    # if (! $netConProfile) {
    #     Write-Warning " * No connection profile found for interface $($adapter.Name) - Cannot configure it"
    #     continue
    # }
    $nameToAdd = if($netConProfile.Name) {
        $netConProfile.Name
    } else {
        $netConProfile.InterfaceAlias
    }
    $nicObj = [NetworkInterface]::new($adapter.Name, $adapter.InterfaceDescription, $nameToAdd)
    $interfacesList += $nicObj
}

# Print the list of network interfaces
for ($i = 0; $i -lt $interfacesList.Count; $i++) {
    $nic = $interfacesList[$i]
    Write-Host "  $($i + 1)) " -NoNewLine
    Write-Host "$($nic.Name)" -ForegroundColor Cyan -NoNewLine
    Write-Host " - $($nic.ConnectionProfileName) - $($nic.Description)" -ForegroundColor Magenta
}

# Add abort option at the end
if ($interfacesList.Count -gt 1) {
    $abortOption = $interfacesList.Count + 1
    Write-Host "  $abortOption) " -NoNewLine
    Write-Host "Abort script" -ForegroundColor Red
}
Write-Host ""

# Check if there is more than one interface
if ($interfacesList.Count -gt 1) {
    Write-Host "Multiple network interfaces found. Please choose one to configure:" -ForegroundColor Yellow
    Write-Host ""

    $validChoice = $false

    if ($Interface) {
        # First check if its an integer (index) 
        if ($Interface -match '^\d+$') {
            $index = [int]$Interface - 1
            if ($index -ge 0 -and $index -lt $interfacesList.Count) {
                $interfaceToConfigure = $interfacesList[$index]
                Write-Host "Auto-selected interface by index: $($interfaceToConfigure.Name) - $($interfaceToConfigure.ConnectionProfileName) - $($interfaceToConfigure.Description)" -ForegroundColor Green
                $validChoice = $true
            }
        } else {
            # Its a string - try to match by name
            $matched = $interfacesList | Where-Object { $_.Name -like "${Interface}*" }
            if ($matched.Count -eq 1) {
                $interfaceToConfigure = $matched
                Write-Host "Auto-selected interface by name match: $($interfaceToConfigure.Name) - $($interfaceToConfigure.ConnectionProfileName) - $($interfaceToConfigure.Description)" -ForegroundColor Green
                $validChoice = $true
            } elseif ($matched.Count -gt 1) {
                Write-Host "Warning: Multiple matches found for param '$Interface', please choose manually." -ForegroundColor Yellow
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
    # Continue with the single interface
	Write-Host "OK - Only one network interface found. Using it.."
    $interfaceToConfigure = $interfacesList[0]
}

Write-Host "Using network interface: $($interfaceToConfigure.Name)" -ForegroundColor Green

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
		Write-Host " * " -NoNewLine ; Write-Host $dnsServer -NoNewLine -ForegroundColor Cyan ; Write-Host "  <-- DNS Already Configured" -ForegroundColor Magenta
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