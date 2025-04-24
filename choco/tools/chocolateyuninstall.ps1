$ErrorActionPreference = 'Stop' # Stop on all errors


# Remove the Chocolatey shim created by Install-BinFile
Uninstall-BinFile -Name 'inet-config'
