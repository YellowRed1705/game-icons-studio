[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Compile the native Windows 10/11 Explorer dialog COM declarations without
# showing a modal window during CI.
. (Join-Path $PSScriptRoot '..\data\src\ModernDialogs.ps1')
if (-not (Test-ModernFileDialogAvailable)) {
    throw 'Modern Windows file/folder picker type did not compile.'
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

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('GIS-Shortcut-Compatibility-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$shell = $null

try {
    $emulatorPath = Join-Path $testRoot 'Test Emulator.exe'
    $romPath = Join-Path $testRoot 'Test Game.gba'
    $urlPath = Join-Path $testRoot 'Test Steam Game.url'
    $icoPath = Join-Path $testRoot 'Test Game.ico'
    [System.IO.File]::WriteAllText($emulatorPath,'test executable placeholder')
    [System.IO.File]::WriteAllText($romPath,'test rom placeholder')
    [System.IO.File]::WriteAllText($urlPath,("[InternetShortcut]" + [Environment]::NewLine + "URL=steam://rungameid/123456"))

    # Minimal ICO directory header used to test application-side ICO
    # validation and shortcut persistence (without rendering test pixels).
    [byte[]]$icoBytes = @(0,0,1,0,1,0,1,1,0,0,1,0,1,0,22,0,0,0,2,0,0,0)
    [System.IO.File]::WriteAllBytes($icoPath,$icoBytes)
    if (-not (Test-ValidIcoFile -Path $icoPath)) { throw 'ICO validator rejected a structurally valid test icon.' }

    foreach ($uri in @(
        'steam://rungameid/123456',
        'com.epicgames.launcher://apps/test?action=launch',
        'uplay://launch/1234/0',
        'battlenet://WTCG',
        'link2ea://launchgame/1234'
    )) {
        if (-not (Test-SupportedLauncherUri -Url $uri)) { throw "Known launcher URI was rejected: $uri" }
    }

    $internetLinks = @(Get-InternetShortcuts -Folder $testRoot)
    if ($internetLinks.Count -ne 1 -or $internetLinks[0].Url -ne 'steam://rungameid/123456') {
        throw 'Internet Shortcut discovery did not return the expected Steam launcher URI.'
    }

    $convertedPath = Convert-InternetShortcut -Shortcut $internetLinks[0] -RemoveOriginal:$false
    if ([string]::IsNullOrWhiteSpace($convertedPath) -or -not (Test-Path -LiteralPath $convertedPath -PathType Leaf)) {
        throw 'URL-to-LNK conversion did not produce a Windows shortcut.'
    }
    if (-not (Test-Path -LiteralPath $urlPath -PathType Leaf)) {
        throw 'URL conversion removed its source even though RemoveOriginal was false.'
    }

    $shell = Get-WshShell
    $converted = $shell.CreateShortcut($convertedPath)
    $expectedExplorer = Join-Path $env:WINDIR 'explorer.exe'
    if ([string]$converted.TargetPath -ine $expectedExplorer -or
        ([string]$converted.Arguments).IndexOf('steam://rungameid/123456',[System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw 'Converted launcher shortcut did not preserve the protocol URI.'
    }

    $generated = @(Get-ShortcutsFromPaths -Paths @($romPath))
    if ($generated.Count -ne 1 -or -not [bool]$generated[0].IsGeneratedFileShortcut) {
        throw 'ROM-to-companion-shortcut planning failed.'
    }
    if ([System.IO.Path]::GetExtension([string]$generated[0].Path) -ine '.lnk') {
        throw 'ROM shortcut plan did not use the standard .lnk extension.'
    }

    $arguments = '"' + $romPath + '"'
    Set-FileCustomIconShortcut -FilePath $romPath -ShortcutPath ([string]$generated[0].Path) -IcoPath $icoPath -LaunchTargetPath $emulatorPath -LaunchArguments $arguments -LaunchWorkingDirectory $testRoot
    $romLink = $shell.CreateShortcut([string]$generated[0].Path)
    if ([string]$romLink.TargetPath -ine $emulatorPath -or [string]$romLink.Arguments -ne $arguments) {
        throw 'ROM shortcut did not preserve the configured emulator launch command.'
    }

    $originalTarget = [string]$converted.TargetPath
    $originalArguments = [string]$converted.Arguments
    Set-ShortcutIcon -ShortcutPath $convertedPath -IcoPath $icoPath
    $verified = $shell.CreateShortcut($convertedPath)
    if ([string]$verified.TargetPath -ne $originalTarget -or [string]$verified.Arguments -ne $originalArguments) {
        throw 'Changing the shortcut icon modified the original launch command.'
    }
    if (([string]$verified.IconLocation -split ',')[0].Trim('"') -ine $icoPath) {
        throw 'Custom ICO path was not persisted on the shortcut.'
    }

    $health = Get-FolderHealth -Folder $testRoot
    if ($health.lnk -lt 2 -or $health.url -ne 1) {
        throw "Folder health scan returned incorrect counts: LNK=$($health.lnk), URL=$($health.url)."
    }

    Write-Host 'Shortcut compatibility tests passed: modern picker COM, Steam/Epic/Ubisoft/Battle.net/EA URI schemes, URL parsing and conversion, ROM emulator launch, ICO persistence, folder health.'
}
finally {
    try { if ($shell) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } } catch { }
    try { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
