[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OutputDirectory = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'release-output')
)

$ErrorActionPreference = 'Stop'
$Version = $Version.Trim()
if ($Version.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase)) { $Version = $Version.Substring(1) }
if ($Version -notmatch '^\d+\.\d+$') { throw "Version must look like 6.35 (without a leading v). Received: '$Version'" }

$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$changelogName = "CHANGELOG-v$Version.md"
$instructionsName = "UPGRADE-INSTRUCTIONS-v$Version.txt"
$documentationFiles = @('README.md', 'LICENSE', $changelogName, $instructionsName)
$runtimeFiles = @(
    'Game Icons Studio.bat',
    'data/Create-Shortcut.ps1',
    'data/Assets/app.ico',
    'data/Assets/brand.png'
)
$moduleDir = Join-Path $RepositoryRoot 'data/src'
if (-not (Test-Path -LiteralPath $moduleDir -PathType Container)) { throw "Missing runtime module folder: $moduleDir" }
$runtimeFiles += @(Get-ChildItem -LiteralPath $moduleDir -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object { 'data/src/' + $_.Name })
$fullFiles = @($runtimeFiles + $documentationFiles)
$upgradeFiles = @($runtimeFiles + @($changelogName, $instructionsName))

foreach ($relative in $fullFiles) {
    $source = Join-Path $RepositoryRoot ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Required release file is missing: $relative" }
}

# Refuse to publish a mismatched version or a missing matching changelog.
$readmeText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'README.md') -Raw
$launcherText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'Game Icons Studio.bat') -Raw
$mainText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'data/src/Main.ps1') -Raw
$webText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'data/src/WebApp.ps1') -Raw
$backupText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'data/src/IconBackup.ps1') -Raw
$imageSearchText = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'data/src/ImageSearch.ps1') -Raw
if ($readmeText -notmatch [regex]::Escape("# Game Icons Studio v$Version")) { throw "README title does not match v$Version" }
if ($launcherText -notmatch [regex]::Escape("title Game Icons Studio v$Version")) { throw "Launcher title does not match v$Version" }
if ($mainText -notmatch [regex]::Escape("GAME ICONS STUDIO  v$Version")) { throw "Main banner does not match v$Version" }
if ($webText -notmatch [regex]::Escape("<title>Game Icons Studio v$Version</title>")) { throw "Web UI title does not match v$Version" }
if ($backupText -notmatch [regex]::Escape("AppVersion = '$Version'")) { throw "Restore-point AppVersion does not match v$Version" }
if ($imageSearchText -notmatch [regex]::Escape("Game-Icons-Studio/$Version")) { throw "Image-search user agent does not match v$Version" }

$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { Remove-Item -LiteralPath $OutputDirectory -Recurse -Force }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stage = Join-Path $OutputDirectory '_stage'
$fullRoot = Join-Path $stage "Game-Icons-Studio-v$Version"
$upgradeRoot = Join-Path $stage 'UpgradeOverlay'
New-Item -ItemType Directory -Path $fullRoot -Force | Out-Null
New-Item -ItemType Directory -Path $upgradeRoot -Force | Out-Null

function Copy-FileSet {
    param([string]$Root, [string]$Destination, [string[]]$RelativePaths)
    foreach ($relative in $RelativePaths) {
        $source = Join-Path $Root ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        $target = Join-Path $Destination ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

# Full distribution is explicitly allow-listed and wrapped in a versioned folder.
Copy-FileSet -Root $RepositoryRoot -Destination $fullRoot -RelativePaths $fullFiles
# Upgrade overlay contains all runtime dependencies at archive root and excludes user data.
Copy-FileSet -Root $RepositoryRoot -Destination $upgradeRoot -RelativePaths $upgradeFiles

$fullZip = Join-Path $OutputDirectory "Game-Icons-Studio-v$Version.zip"
$upgradeZip = Join-Path $OutputDirectory "Game-Icons-Studio-v$Version-Upgrade.zip"
if (Test-Path -LiteralPath $fullZip) { Remove-Item -LiteralPath $fullZip -Force }
if (Test-Path -LiteralPath $upgradeZip) { Remove-Item -LiteralPath $upgradeZip -Force }
Compress-Archive -Path $fullRoot -DestinationPath $fullZip -CompressionLevel Optimal
Compress-Archive -Path (Join-Path $upgradeRoot '*') -DestinationPath $upgradeZip -CompressionLevel Optimal

$releaseNotes = Join-Path $OutputDirectory 'ReleaseNotes.md'
Copy-Item -LiteralPath (Join-Path $RepositoryRoot $changelogName) -Destination $releaseNotes -Force
$hashes = @{}
foreach ($path in @($fullZip, $upgradeZip)) {
    $hashes[[System.IO.Path]::GetFileName($path)] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}
$hashes | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS.json') -Encoding UTF8
Remove-Item -LiteralPath $stage -Recurse -Force
Write-Host "Built release v$Version"
Write-Host "Full:    $fullZip"
Write-Host "Upgrade: $upgradeZip"
Write-Host "Notes:   $releaseNotes"
