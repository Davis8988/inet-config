$ErrorActionPreference = 'Stop'

# Get the absolute tools directory path
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exePath  = Join-Path $toolsDir 'inet-config.bat'

# If you are embedding the script, use $exePath as 'file' instead of downloading
$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  fileType       = 'exe'
  file           = $exePath
  softwareName   = 'inet-config*'
  silentArgs     = ''
  validExitCodes = @(0)
}

# Install the shim to allow global execution of `inet-config`
Install-ChocolateyInstallPackage @packageArgs

# Create a command alias (shim) to run the tool globally from the command line
Install-BinFile -Name 'inet-config' -Path $exePath
