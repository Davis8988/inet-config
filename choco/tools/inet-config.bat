@echo off
setlocal EnableDelayedExpansion

:: ############################################################
:: inet-config.bat - Entrypoint for DNS configuration scripts
::
:: Author: David Yair [E030331]
::
:: Description:
::   This batch script wraps and dispatches execution to either:
::     - add-dns.ps1
::     - remove-dns.ps1
::
:: Usage:
::   inet-config.bat add-dns   [parameters...]
::   inet-config.bat remove-dns [parameters...]
::
:: Notes:
::   - The first argument must be the PowerShell script name.
::   - All additional arguments will be forwarded as-is to the target script.
:: ############################################################

:: Check if a script was provided
if "%~1"=="" (
    echo [ERROR] No script specified. Usage: inet-config.bat ^<add-dns^|remove-dns^> [args...]
    exit /b 1
)

:: Set the script name
set "scriptName=%~1"
shift

:: Verify script exists
if not exist "%~dp0powershell\%scriptName%.ps1" (
    echo [ERROR] Script "%scriptName%.ps1" not found at: "%~dp0powershell\%scriptName%.ps1"
    exit /b 1
)

:: Compose the PowerShell execution command
set "psCommand=powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0powershell\%scriptName%.ps1" %*"

echo Running: %psCommand%
echo.

:: Execute
%psCommand%
exit /b %ERRORLEVEL%
