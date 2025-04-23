$ErrorActionPreference = 'Stop' # Stop on all errors

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  softwareName   = 'inet-config*'
  fileType       = 'EXE' # No MSI used here, only script files
  silentArgs     = ''
  validExitCodes = @(0, 3010, 1605, 1614, 1641)
}

# Attempt to locate uninstall info in registry (if applicable)
[array]$key = Get-UninstallRegistryKey -SoftwareName $packageArgs['softwareName']

if ($key.Count -eq 1) {
  $key | ForEach-Object {
    $packageArgs['file'] = "$($_.UninstallString)"

    # Sanitize uninstall path if needed
    $packageArgs['file'] = $packageArgs['file'] -replace '"',''

    Uninstall-ChocolateyPackage @packageArgs
  }
} elseif ($key.Count -eq 0) {
  Write-Warning "$($packageArgs.packageName) has already been uninstalled or was not found in Programs and Features."
} elseif ($key.Count -gt 1) {
  Write-Warning "$($key.Count) matches found!"
  Write-Warning "To prevent accidental data loss, no uninstall will be performed."
  Write-Warning "Please report to the package maintainer the following matched entries:"
  $key | ForEach-Object { Write-Warning "- $($_.DisplayName)" }
}

# Remove the Chocolatey shim created by Install-BinFile
Uninstall-BinFile -Name 'inet-config'
