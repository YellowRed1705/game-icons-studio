# ============================================================
#  Create-Shortcut.ps1 - Game Icons Studio
#  Creates a custom-icon "Game Icons Studio.lnk" in the app folder
#  (and optionally on the Desktop) that launches the .bat. This is
#  the safe, exe-like launcher: double-clickable, custom icon, no
#  antivirus false positives, no SmartScreen warnings.
#
#  Run once:  pwsh -File "Create-Shortcut.ps1"
# ============================================================

param(
    [switch]$Desktop
)

$ErrorActionPreference = 'Stop'
# This script lives in the data\ folder. The shortcut, however, must
# point at the launcher in the MAIN folder (data's parent) and use the
# icon under data\Assets.
$dataDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root    = Split-Path -Parent $dataDir          # main app folder
$bat     = Join-Path $root 'Game Icons Studio.bat'
$ico     = Join-Path $dataDir 'Assets\app.ico'

if (-not (Test-Path $bat)) {
    Write-Host "Launcher not found: $bat" -ForegroundColor Red
    return
}

function New-AppShortcut {
    param([string]$LinkPath)
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($LinkPath)
    $sc.TargetPath       = $bat
    $sc.WorkingDirectory = $root
    $sc.Description       = 'Game Icons Studio - From generic icons to a game shelf.'
    $sc.WindowStyle       = 1
    if (Test-Path $ico) { $sc.IconLocation = "$ico,0" }
    $sc.Save()
    Write-Host "Created: $LinkPath" -ForegroundColor Green
}

# Always (re)create the in-folder shortcut
New-AppShortcut -LinkPath (Join-Path $root 'Game Icons Studio.lnk')

# Optionally also on the Desktop
if ($Desktop) {
    $desk = [Environment]::GetFolderPath('Desktop')
    New-AppShortcut -LinkPath (Join-Path $desk 'Game Icons Studio.lnk')
}

Write-Host ''
Write-Host 'Done. Double-click "Game Icons Studio" to launch.' -ForegroundColor Cyan
