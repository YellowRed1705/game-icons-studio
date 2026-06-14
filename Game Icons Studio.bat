@echo off
title Game Icons Studio
setlocal
cd /d "%~dp0"

rem ============================================================
rem  Game Icons Studio - Launcher
rem  From generic icons to a game shelf.
rem  Everything lives under data\ ; only this launcher and the
rem  shortcut sit in the main folder.
rem ============================================================

rem One-time: create the custom-icon shortcut in the main folder
if not exist "%~dp0Game Icons Studio.lnk" (
    where pwsh >nul 2>&1
    if %errorlevel%==0 (
        pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0data\Create-Shortcut.ps1" >nul 2>&1
    ) else (
        powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0data\Create-Shortcut.ps1" >nul 2>&1
    )
)

where pwsh >nul 2>&1
if %errorlevel%==0 (
    pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0data\src\Main.ps1"
) else (
    echo [INFO] PowerShell 7 not found. Falling back to Windows PowerShell 5.1.
    echo [INFO] Parallel downloads will be disabled. Install PowerShell 7 for best performance.
    echo.
    powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0data\src\Main.ps1"
)

rem Close automatically on a clean exit; pause only if something failed.
if errorlevel 1 (
    echo.
    echo Something went wrong. Press a key to close.
    pause >nul
)
endlocal
exit
