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
::   - The first argument is the script name (without extension).
::   - All additional arguments will be passed to the target script.
:: ############################################################

:: Check if a script was provided
if "%~1"=="" (
    echo [ERROR] No script specified. Usage: inet-config.bat ^<add-dns^|remove-dns^> [args...]
    exit /b 1
)

:: Set and shift the script name
set "scriptName=%~1"
shift

:: Rebuild the remaining arguments into args
set "args="
:collectArgs
if "%~1"=="" goto endArgs
set args=!args! "%~1"
shift
goto collectArgs
:endArgs

:: Verify script exists
set "scriptPath=%~dp0powershell\%scriptName%.ps1"
if not exist "!scriptPath!" (
    echo [ERROR] Script "%scriptName%.ps1" not found at: "!scriptPath!"
    exit /b 1
)

:: Compose the PowerShell execution command
set "psCommand=powershell.exe -ExecutionPolicy Bypass -NoProfile -File "!scriptPath!" !args!"

echo Running: !psCommand!
echo.

:: Execute
%psCommand%
exit /b %ERRORLEVEL%
