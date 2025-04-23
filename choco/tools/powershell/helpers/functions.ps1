function getTargetInterface {
    param (
        [Parameter(Mandatory = $true)]
        [array]$interfacesList,

        [string]$Interface,

        [switch]$AutoConfirm
    )

    if ($interfacesList.Count -eq 0) {
        Write-Host "No interfaces available." -ForegroundColor Red
        exit 1
    }

    # Print the list of network interfaces
    for ($i = 0; $i -lt $interfacesList.Count; $i++) {
        $nic = $interfacesList[$i]
        Write-Host "  $($i + 1)) " -NoNewLine
        Write-Host "$($nic.Name)" -ForegroundColor Cyan -NoNewLine
        Write-Host " - $($nic.ConnectionProfileName) - $($nic.Description)" -ForegroundColor Magenta
    }

    if ($interfacesList.Count -eq 1) {
        Write-Host "OK - Only one network interface found. Using it.." -ForegroundColor Green
        return $interfacesList[0]
    }

    # Add abort option
    $abortOption = $interfacesList.Count + 1
    Write-Host "  $abortOption) Abort script" -ForegroundColor Red
    Write-Host ""

    if ($AutoConfirm -and ! $Interface) {
        Write-Host "Auto-confirmation enabled but no interface specified. Cannot auto-select." -ForegroundColor Red
        Write-Host "Please specify an interface using the -Interface parameter. (e.g. -Interface=1)" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Multiple network interfaces found. Please choose one to configure:" -ForegroundColor Yellow
    Write-Host ""

    $validChoice = $false
    $interfaceToConfigure = $null

    if ($Interface) {
        if ($Interface -match '^\d+$') {
            $index = [int]$Interface - 1
            if ($index -ge 0 -and $index -lt $interfacesList.Count) {
                $interfaceToConfigure = $interfacesList[$index]
                Write-Host "Auto-selected interface by index: $($interfaceToConfigure.Name) - $($interfaceToConfigure.ConnectionProfileName) - $($interfaceToConfigure.Description)" -ForegroundColor Green
                return $interfaceToConfigure
            }
        } else {
            $matched = $interfacesList | Where-Object { $_.Name -like "${Interface}*" }
            if ($matched.Count -eq 1) {
                $interfaceToConfigure = $matched
                Write-Host "Auto-selected interface by name match: $($interfaceToConfigure.Name) - $($interfaceToConfigure.ConnectionProfileName) - $($interfaceToConfigure.Description)" -ForegroundColor Green
                return $interfaceToConfigure
            } elseif ($matched.Count -gt 1) {
                Write-Host "Warning: Multiple matches found for '$Interface', please choose manually." -ForegroundColor Yellow
            } else {
                Write-Host "Could not find interface matching '$Interface'. Please choose manually." -ForegroundColor Yellow
            }
        }
    }

    while (-not $validChoice) {
        $choice = Read-Host "Enter the number of the interface you want to configure ($abortOption to abort)"

        if ($choice -match '^\d+$') {
            $choiceInt = [int]$choice

            if ($choiceInt -eq $abortOption) {
                Write-Host "User aborted interface selection." -ForegroundColor Red
                exit 0
            }

            if ($choiceInt -ge 1 -and $choiceInt -le $interfacesList.Count) {
                $index = $choiceInt - 1
                $interfaceToConfigure = $interfacesList[$index]
                Write-Host "You chose: $($interfaceToConfigure.Name) - $($interfaceToConfigure.ConnectionProfileName) - $($interfaceToConfigure.Description)" -ForegroundColor Green
                $validChoice = $true
            } else {
                Write-Host "Invalid choice. Please enter a number between 1 and $($interfacesList.Count), or $abortOption to abort." -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid input. Please enter a numeric value." -ForegroundColor Red
        }
    }

    return $interfaceToConfigure
}

function getDnsServersForInterface {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InterfaceName
    )

    $dnsServers = (Get-DnsClientServerAddress -InterfaceAlias $InterfaceName -AddressFamily IPv4).ServerAddresses
    return $dnsServers
}


function printDnsServersForInterface {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InterfaceName,

        [array]$DnsServers,

        [string]$HighlightDns
    )

    # Get existing DNS servers
    if (! $DnsServers) {
        $dnsServers = (Get-DnsClientServerAddress -InterfaceAlias $InterfaceName -AddressFamily IPv4).ServerAddresses
    }

    Write-Host ""
    Write-Host "Interface `"$InterfaceName`" Current configured DNS servers:" -ForegroundColor Yellow

    foreach ($dns in $dnsServers) {
        Write-Host " * " -NoNewLine
        if ($HighlightDns -and $dns -eq $HighlightDns) {
            Write-Host $dns -ForegroundColor Cyan
        } else {
            Write-Host $dns
        }
    }
}
