[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Compile native Windows picker/foreground helpers without opening a modal dialog.
. (Join-Path $PSScriptRoot '..\data\src\ModernDialogs.ps1')
if (-not (Test-ModernFileDialogAvailable)) {
    throw 'Modern Windows file/folder picker type did not compile.'
}
$nativeWindowTools = 'GIS.NativeWindowTools' -as [type]
if (-not $nativeWindowTools) { throw 'Native window helper did not compile.' }
foreach ($methodName in @('GetForegroundWindowHandle','ShowMaximizedAndForeground','WatchAndMaximizeDialog')) {
    if (-not $nativeWindowTools.GetMethod($methodName)) { throw "Native window helper is missing method $methodName." }
}
[void][GIS.NativeWindowTools]::GetForegroundWindowHandle()

# Browser UI: languages, fresh-install English default and mixed scan/apply wiring.
$webAppPath = Join-Path $PSScriptRoot '..\data\src\WebApp.ps1'
$webAppText = Get-Content -LiteralPath $webAppPath -Raw
foreach ($languageCode in @('en','tr','ar')) {
    if ($webAppText -notmatch ('data-lang="' + $languageCode + '"')) {
        throw "Language selector is missing its $languageCode flag button."
    }
}
if ($webAppText -notmatch "var currentLang = 'en';" -or
    $webAppText -notmatch "localStorage\.getItem\('gis-lang-v2'\)" -or
    $webAppText -match "localStorage\.getItem\('gis-lang'\)") {
    throw 'Fresh installs must default to English and use the current language preference key.'
}
foreach ($token in @('function setLang(lang)','function applyScreenLanguage(screen)','lang-flag','scanIconSearchOnly','res.item.iconSearchOnly','it.iconSearchOnly')) {
    if ($webAppText -notmatch [regex]::Escape($token)) { throw "Browser UI is missing required wiring: $token" }
}

$webServerPath = Join-Path $PSScriptRoot '..\data\src\WebServer.ps1'
$webServerText = Get-Content -LiteralPath $webServerPath -Raw
if ($webServerText -notmatch 'ShowMaximizedAndForeground\(\$hwnd\)' -or
    $webServerText -notmatch '\$attempt -lt 30') {
    throw 'Post-apply Explorer must be maximized and focused.'
}
foreach ($token in @('ProgramIconNames','IsProgramIcon','Get-EmulatorLauncherFamily','ryujinx|ryubing')) {
    if ($webServerText -notmatch [regex]::Escape($token)) { throw "Game Library emulator-app routing is missing: $token" }
}
$modernDialogText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\data\src\ModernDialogs.ps1') -Raw
if ($modernDialogText -notmatch 'WatchAndMaximizeDialog\(dialogTitle, activeOwner\)' -or
    $modernDialogText -notmatch 'dialog\.Show\(activeOwner\)') {
    throw 'Native pickers must use the active owner and foreground/maximize watcher.'
}

function Write-Log {
    param([string]$Message,[string]$Level='INFO',[bool]$Show=$false)
}
function Get-SafeFileName {
    param([Parameter(Mandatory)][string]$Name)
    $safe = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    $safe = $safe -replace '[<>:"/\\|?*\x00-\x1F]', '_'
    return $safe.Trim().TrimEnd('.')
}

. (Join-Path $PSScriptRoot '..\data\src\ShortcutTools.ps1')
. (Join-Path $PSScriptRoot '..\data\src\IconTools.ps1')
. (Join-Path $PSScriptRoot '..\data\src\IconBackup.ps1')

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('GIS-Shortcut-Compatibility-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$shell = $null

try {
    $shell = Get-WshShell

    # Real Windows .lnk regression: plain launcher shortcuts are app icons.
    # Cemu/Eden/Ryubing ROM shortcuts with arguments remain game links.
    $emulatorCases = @(
        @{ Name = 'Cemu'; Family = 'cemu' },
        @{ Name = 'Eden'; Family = 'eden' },
        @{ Name = 'Ryubing'; Family = 'ryujinx' }
    )
    foreach ($case in $emulatorCases) {
        $fakeExe = Join-Path $testRoot ($case.Name + '.exe')
        $fakeLink = Join-Path $testRoot ($case.Name + '.lnk')
        [System.IO.File]::WriteAllText($fakeExe,'test emulator executable placeholder')
        $launcher = $shell.CreateShortcut($fakeLink)
        $launcher.TargetPath = $fakeExe
        $launcher.Arguments = ''
        $launcher.Save()
        $readBack = $shell.CreateShortcut($fakeLink)
        $family = Get-EmulatorLauncherFamily -TargetPath ([string]$readBack.TargetPath) -Arguments ([string]$readBack.Arguments)
        if ($family -ne $case.Family) {
            throw "$($case.Name) launcher was classified as '$family' instead of '$($case.Family)'."
        }
        $romFamily = Get-EmulatorLauncherFamily -TargetPath ([string]$readBack.TargetPath) -Arguments '"test-game.nsp"'
        if (-not [string]::IsNullOrWhiteSpace($romFamily)) {
            throw "$($case.Name) ROM launch shortcut was incorrectly classified as an application icon."
        }
    }

    # Verify the same icon write path used by the app preserves the shortcut's
    # original launch target and command-line arguments.
    $emulatorPath = Join-Path $testRoot 'Test Emulator.exe'
    $urlPath = Join-Path $testRoot 'Test Steam Game.url'
    $icoPath = Join-Path $testRoot 'Test Game.ico'
    [System.IO.File]::WriteAllText($emulatorPath,'test executable placeholder')
    [System.IO.File]::WriteAllText($urlPath,("[InternetShortcut]" + [Environment]::NewLine + "URL=steam://rungameid/123456"))

    [byte[]]$icoBytes = @(0,0,1,0,1,0,1,1,0,0,1,0,1,0,22,0,0,0,2,0,0,0)
    [System.IO.File]::WriteAllBytes($icoPath,$icoBytes)
    if (-not (Test-ValidIcoFile -Path $icoPath)) { throw 'ICO validator rejected a structurally valid test icon.' }

    $urlEntries = @(Get-InternetShortcuts -Folder $testRoot)
    if ($urlEntries.Count -ne 1 -or $urlEntries[0].Url -ne 'steam://rungameid/123456') {
        throw 'Internet Shortcut discovery did not return the expected Steam launcher URI.'
    }
    $convertedPath = Convert-InternetShortcut -Shortcut $urlEntries[0] -RemoveOriginal:$false
    if ([string]::IsNullOrWhiteSpace($convertedPath) -or -not (Test-Path -LiteralPath $convertedPath -PathType Leaf)) {
        throw 'URL-to-LNK conversion did not produce a Windows shortcut.'
    }
    if (-not (Test-Path -LiteralPath $urlPath -PathType Leaf)) { throw 'URL conversion removed its source when RemoveOriginal was false.' }

    $converted = $shell.CreateShortcut($convertedPath)
    $originalTarget = [string]$converted.TargetPath
    $originalArguments = [string]$converted.Arguments
    Set-ShortcutIcon -ShortcutPath $convertedPath -IcoPath $icoPath
    $verified = $shell.CreateShortcut($convertedPath)
    if ([string]$verified.TargetPath -ne $originalTarget -or [string]$verified.Arguments -ne $originalArguments) {
        throw 'Changing a shortcut icon modified its original launch command.'
    }
    if (([string]$verified.IconLocation -split ',')[0].Trim('"') -ine $icoPath) {
        throw 'Custom ICO path was not persisted on the shortcut.'
    }

    # Verify Undo restores an existing source file and removes a newly created link.
    $backupFolder = Join-Path $testRoot 'backup-transaction'
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
    $restoreSource = Join-Path $testRoot 'Undo Source.url'
    [System.IO.File]::WriteAllText($restoreSource,'[InternetShortcut]')
    $sourceRecord = Add-IconBackupFile -OriginalPath $restoreSource -TransactionFolder $backupFolder -ItemNumber 1 -FileNumber 1
    Remove-Item -LiteralPath $restoreSource -Force
    Restore-IconBackupFile -FileRecord $sourceRecord -TransactionFolder $backupFolder
    if (-not (Test-Path -LiteralPath $restoreSource) -or [System.IO.File]::ReadAllText($restoreSource) -ne '[InternetShortcut]') {
        throw 'Undo file backup did not restore the original URL shortcut.'
    }
    $newShortcut = Join-Path $testRoot 'New Generated Shortcut.lnk'
    [System.IO.File]::WriteAllText($newShortcut,'new shortcut placeholder')
    $newRecord = Add-IconBackupFile -OriginalPath $newShortcut -TransactionFolder $backupFolder -ItemNumber 2 -FileNumber 1 -AssumeMissing
    if ([bool]$newRecord.Existed) { throw 'A newly generated shortcut was incorrectly marked as existing.' }
    Restore-IconBackupFile -FileRecord $newRecord -TransactionFolder $backupFolder
    if (Test-Path -LiteralPath $newShortcut) { throw 'Undo did not remove a newly generated shortcut.' }

    Write-Host 'Shortcut compatibility tests passed: native picker, EN/TR/AR UI, Cemu/Eden/Ryubing detection, ROM link separation, launcher conversion, ICO persistence and Undo.'
}
finally {
    try { if ($shell) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } } catch { }
    try { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
