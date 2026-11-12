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
    $webAppText -notmatch "localStorage\.getItem\('gis-lang-v3'\)" -or
    $webAppText -match "localStorage\.getItem\('gis-lang'\)") {
    throw 'Fresh installs must default to English and use the current language preference key.'
}
foreach ($token in @('function setLang(lang)','function applyScreenLanguage(screen)','lang-flag','scanIconSearchOnly','res.item.iconSearchOnly','it.iconSearchOnly')) {
    if ($webAppText -notmatch [regex]::Escape($token)) { throw "Browser UI is missing required wiring: $token" }
}

$webServerPath = Join-Path $PSScriptRoot '..\data\src\WebServer.ps1'
$webServerText = Get-Content -LiteralPath $webServerPath -Raw

# Ten workflow regression categories: saved picks, manual editing, path-based
# new-file discovery and reliable shortcut icon persistence.
foreach ($token in @(
    'state.useMemory = true;',
    'if (it.remembered && it.savedUrl) applyRememberedCover(it);',
    'if (state.autoAll && !state.editReturnToReview)',
    'state.autoAll = false;',
    'function scanGameFilesFolder(folder, onlyNew)',
    'onlyNew: state.onlyNew',
    'function Get-GameLibraryInventoryPaths',
    'function Get-NewInventoryPaths',
    'Save-KnownShortcutFiles',
    'Get-ScanInventoryKey'
)) {
    if (-not $webAppText.Contains($token) -and -not $webServerText.Contains($token)) {
        throw "Scan workflow regression guard is missing: $token"
    }
}
if ($webServerText -notmatch 'Get-GameLibraryInventoryPaths -Folder \$Session.ScanInventoryFolder -Mode \$Session.ScanInventoryMode' -or
    $webServerText -notmatch 'Save-KnownShortcutFiles -Root \$Session.Root') {
    throw 'Completed scan inventory must be persisted after apply, not at scan start.'
}
if ($webServerText -notmatch 'OnlyNewPaths\.ContainsKey' -or
    $webServerText -notmatch 'shortcutsToInclude' -or
    $webServerText -notmatch '\$candidateFiles = @\(\$candidateFiles') {
    throw 'Only-new filtering must cover .lnk, .url, EXE, script and ROM targets.'
}
$shortcutToolsText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\data\src\ShortcutTools.ps1') -Raw
foreach ($token in @('for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++)','New-Object -ComObject WScript.Shell','FinalReleaseComObject','Windows did not persist the new icon location')) {
    if (-not $shortcutToolsText.Contains($token)) { throw "Reliable shortcut icon writing is missing: $token" }
}

# Regression: PowerShell 7.7 may throw "Argument types do not match" when
# a Generic.List[object] is wrapped directly with @() inside a hashtable.
# Production code must materialize the list with ToArray() before JSON encoding.
if ($webServerText -notmatch '\$fallbackCoverArray\s*=\s*\$fallbackCovers\.ToArray\(\)' -or
    $webServerText -match 'covers\s*=\s*@\(\$fallbackCovers\)') {
    throw 'Embedded application-icon fallback must convert Generic.List with ToArray() before building JSON.'
}
$fallbackCoverProbe = New-Object 'System.Collections.Generic.List[object]'
$fallbackCoverProbe.Add([PSCustomObject]@{ url = '/cache/regression.png'; thumb = '/cache/regression.png'; score = 100 })
$fallbackCoverArray = $fallbackCoverProbe.ToArray()
$fallbackSection = @(@{ gameId = 0; gameName = 'Embedded icon regression'; year = 0; covers = $fallbackCoverArray })
$fallbackJson = ConvertTo-Json -InputObject $fallbackSection -Depth 8 -Compress
$fallbackRoundTrip = ConvertFrom-Json -InputObject $fallbackJson
if ($fallbackRoundTrip.Count -ne 1 -or
    $fallbackRoundTrip[0].covers.Count -ne 1 -or
    $fallbackRoundTrip[0].covers[0].url -ne '/cache/regression.png') {
    throw 'Embedded application-icon fallback array did not survive JSON serialization.'
}
if ($webServerText -notmatch 'ShowMaximizedAndForeground\(\$hwnd\)' -or
    $webServerText -notmatch '\$attempt -lt 30') {
    throw 'Post-apply Explorer must be maximized and focused.'
}
foreach ($token in @('ProgramIconNames','IsProgramIcon','Get-EmulatorLauncherFamily','ryujinx|ryubing')) {
    if ($webServerText -notmatch [regex]::Escape($token)) { throw "Game Library emulator-app routing is missing: $token" }
}
if (-not $webServerText.Contains("$path -eq '/api/search-games'") -or
    -not $webServerText.Contains('Get-SgdbGameCandidates -ApiKey')) {
    throw 'Manual SteamGridDB game search endpoint is missing.'
}
foreach ($token in @('function searchGameCandidates()','function useCustomGameTitle()','customGameReturnToMatches','customGameName','review-change-game','manualGameI18n')) {
    if (-not $webAppText.Contains($token)) { throw "Manual game selection UI is missing: $token" }
}
if (-not $webAppText.Contains('onclick="toggleLang()"') -or
    -not $webAppText.Contains('.lang-option:not(.active) { display:none !important; }')) {
    throw 'Language selection must use one visible flag button that cycles languages.'
}
foreach ($token in @('grid-template-columns:repeat(4,minmax(0,1fr))','height:clamp(124px,17vh,146px)','#step-home { padding:15px 22px; gap:9px; max-height:none; overflow:visible; }','-webkit-line-clamp:3')) {
    if (-not $webAppText.Contains($token)) { throw "Compact, no-scroll home dashboard rule is missing: $token" }
}
if (-not $webAppText.Contains('@media (max-width:780px)') -or
    -not $webAppText.Contains('grid-template-columns:repeat(2,minmax(0,1fr))')) {
    throw 'Compact home dashboard must remain responsive on small screens.'
}
if (-not $webAppText.Contains("api('/api/custom-cover', { name: it.name, dataUrl: pngDataUrl })") -or
    -not $webAppText.Contains('gameName: chosenArtworkName + customSuffix')) {
    throw 'Custom game titles must not replace the original Shortcut name.'
}

if ($webServerText.Contains('Get-OnlineProgramIconCandidates') -or
    $webServerText.Contains("'/api/search-images'")) {
    throw 'Automatic Google/Yandex image fetching must stay removed.'
}
if ($webAppText.Contains('/api/search-images') -or $webAppText.Contains('onlineAutoTop5Btn')) {
    throw 'The retired online Top 5 fetch workflow is still referenced by the browser UI.'
}
if ($webServerText.Contains("'/api/search-images'")) {
    throw 'The retired manual Top 5 image-fetch endpoint must not be exposed.'
}
foreach ($token in @('id="googleImagesBtn"','id="yandexImagesBtn"','function openGoogleSearch()','function openYandexSearch()','function prepareCustomDropTarget','drop-ready','id="customDropZone"','#customCropEditor.visible { display:block; }','img.onload=function(){','#customCropEditor { display:none;','function onCustomCropPointerDown','function zoomCustomCrop','customSourceCanvas','customCropState.crop')) {
    if (-not $webAppText.Contains($token)) { throw "Google/Yandex search and drag-drop workflow is missing: $token" }
}
foreach ($token in @('onlineAutoTop5Btn','googleImageResultsGrid','yandexImageResultsGrid','function searchOnlineImageCandidates','Fetch Top 5 from each','function fetchAndApplyOnlineCandidate')) {
    if ($webAppText.Contains($token)) { throw "Retired manual Top 5 UI is still present: $token" }
}
$iconToolsText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\data\src\IconTools.ps1') -Raw
foreach ($token in @('function New-StyledBitmap','function ConvertTo-Ico','New-RoundedRectPath','CornerRadiusPercent','BorderWidthPercent','ShadowEnabled')) {
    if (-not $iconToolsText.Contains($token)) { throw "Shared ICO shape/style pipeline is missing: $token" }
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

. (Join-Path $PSScriptRoot '..\data\src\Settings.ps1')
. (Join-Path $PSScriptRoot '..\data\src\WebServer.ps1')
. (Join-Path $PSScriptRoot '..\data\src\ShortcutTools.ps1')
. (Join-Path $PSScriptRoot '..\data\src\IconTools.ps1')
. (Join-Path $PSScriptRoot '..\data\src\IconBackup.ps1')

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('GIS-Shortcut-Compatibility-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$shell = $null

try {
    # Path inventory detects same-name items from their distinct full paths.
    $inventoryFolder = Join-Path $testRoot 'inventory'
    New-Item -ItemType Directory -Path $inventoryFolder -Force | Out-Null
    $inventoryLnk = Join-Path $inventoryFolder 'Existing Game.lnk'
    $inventoryExe = Join-Path $inventoryFolder 'New Game.exe'
    $inventoryRom = Join-Path $inventoryFolder 'New Game.nsp'
    $inventoryTxt = Join-Path $inventoryFolder 'readme.txt'
    foreach ($filePath in @($inventoryLnk,$inventoryExe,$inventoryRom,$inventoryTxt)) {
        [System.IO.File]::WriteAllText($filePath, 'inventory test')
    }
    $allInventory = @(Get-GameLibraryInventoryPaths -Folder $inventoryFolder -Mode 'game_files')
    $shortcutInventory = @(Get-GameLibraryInventoryPaths -Folder $inventoryFolder -Mode 'shortcuts')
    if ($allInventory.Count -ne 3 -or $shortcutInventory.Count -ne 1) {
        throw "Game Library inventory mismatch. game_files=$($allInventory.Count), shortcuts=$($shortcutInventory.Count)."
    }
    $newInventory = @(Get-NewInventoryPaths -CurrentPaths $allInventory -KnownPaths @($inventoryLnk))
    if ($newInventory.Count -ne 2 -or $newInventory -notcontains $inventoryExe -or $newInventory -notcontains $inventoryRom) {
        throw 'Only-new path comparison did not return the newly added EXE and ROM.'
    }

    # Persist and reload path inventory while preserving old knownGames.json.
    $inventoryKey = Get-ScanInventoryKey -Folder $inventoryFolder -Mode 'game_files'
    $knownFileMap = @{}
    $knownFileMap[$inventoryKey] = $allInventory
    Save-KnownShortcutFiles -Root $testRoot -Map $knownFileMap
    $knownFileReload = Get-KnownShortcutFiles -Root $testRoot
    if (-not $knownFileReload.ContainsKey($inventoryKey) -or @($knownFileReload[$inventoryKey]).Count -ne 3) {
        throw 'knownShortcutFiles.json did not persist the Game Library inventory.'
    }
    $legacyKnown = @{}
    $legacyKnown[$inventoryFolder.ToLowerInvariant()] = @('Existing Game')
    Save-KnownGames -Root $testRoot -Map $legacyKnown
    $legacyReload = Get-KnownGames -Root $testRoot
    if (-not $legacyReload.ContainsKey($inventoryFolder.ToLowerInvariant()) -or
        @($legacyReload[$inventoryFolder.ToLowerInvariant()]).Count -ne 1) {
        throw 'Legacy knownGames.json compatibility was lost.'
    }

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
    $icoPath2 = Join-Path $testRoot 'Test Game Second.ico'
    [System.IO.File]::WriteAllBytes($icoPath2,$icoBytes)
    if (-not (Test-ValidIcoFile -Path $icoPath) -or -not (Test-ValidIcoFile -Path $icoPath2)) {
        throw 'ICO validator rejected one of the structurally valid test icons.'
    }

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
    # Change the same shortcut a second time with another ICO.
    Set-ShortcutIcon -ShortcutPath $convertedPath -IcoPath $icoPath2
    $verified = $shell.CreateShortcut($convertedPath)
    if ([string]$verified.TargetPath -ne $originalTarget -or [string]$verified.Arguments -ne $originalArguments) {
        throw 'Changing a shortcut icon modified its original launch command.'
    }
    if (([string]$verified.IconLocation -split ',')[0].Trim('"') -ine $icoPath2) {
        throw 'Repeated custom ICO update was not persisted on the shortcut.'
    }
    $singleSelected = @(Get-ShortcutsFromPaths -Paths @($convertedPath))
    if ($singleSelected.Count -ne 1 -or [string]$singleSelected[0].Path -ine $convertedPath) {
        throw 'Selecting one specific shortcut did not produce exactly one editable scan target.'
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

    Write-Host 'Compatibility tests passed: native picker, EN/TR/AR UI, embedded-icon serialization, saved-pick defaults, manual single-item edit, path-based only-new inventory, legacy migration, repeat ICO writes, emulator detection, launcher conversion and Undo.'
}
finally {
    try { if ($shell) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } } catch { }
    try { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
