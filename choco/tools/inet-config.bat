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

:: Check if a script was provided or help requested
if "%~1"=="" (
    goto :showHelp
)

if /I "%~1"=="/?"   goto :showHelp
if /I "%~1"=="-h"   goto :showHelp
if /I "%~1"=="--help" goto :showHelp

:: Proceed normally
set "scriptName=%~1"
shift
goto :continue

:showHelp
echo.
echo Author: David Yair [E030331]
echo inet-config.bat - Entrypoint for DNS configuration scripts
echo.
echo Supported commands:
echo   add-dns       Adds a DNS server to an interface
echo   remove-dns    Removes a DNS server from an interface
echo.
echo Usage:
echo   inet-config.bat add-dns     [args...]
echo   inet-config.bat remove-dns  [args...]
echo.
exit /b 0

:continue


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
