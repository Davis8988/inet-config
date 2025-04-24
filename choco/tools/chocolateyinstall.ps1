$ErrorActionPreference = 'Stop'

# Get the absolute tools directory path
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exePath  = Join-Path $toolsDir 'inet-config.bat'

# Create a command alias (shim) to run the tool globally from the command line
Install-BinFile -Name 'inet-config' -Path $exePath
