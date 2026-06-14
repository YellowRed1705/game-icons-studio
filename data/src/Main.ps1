# ============================================================
#  Main.ps1 - Game Icons Studio (v6.0)
#  Menu: Full Auto | Smart Auto | Manual | Selected Files Only
#        Revision | Manual Search | Rebuild | Cache
# ============================================================

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# $ScriptDir is where the .ps1 modules live (the 'src' folder).
# $Root is the application root (its parent) where user-facing data
# lives: settings.json, overrides.json, Cache, Logs, Icons.
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$Root = Split-Path -Parent $ScriptDir
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = $ScriptDir }

# ---- Load modules (from the src folder) ----
. (Join-Path $ScriptDir 'Logger.ps1')
. (Join-Path $ScriptDir 'UiTools.ps1')
. (Join-Path $ScriptDir 'Settings.ps1')
. (Join-Path $ScriptDir 'ShortcutTools.ps1')
. (Join-Path $ScriptDir 'SteamGridDB.ps1')
. (Join-Path $ScriptDir 'IconTools.ps1')
. (Join-Path $ScriptDir 'ExplorerRefresh.ps1')
. (Join-Path $ScriptDir 'Maintenance.ps1')
. (Join-Path $ScriptDir 'SelectionPage.ps1')
. (Join-Path $ScriptDir 'Workflows.ps1')
. (Join-Path $ScriptDir 'WebServer.ps1')
. (Join-Path $ScriptDir 'WebApp.ps1')

function Show-Banner {
    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
    Write-Host '   GAME ICONS STUDIO  v6.27' -ForegroundColor Cyan
    Write-Host '   From generic icons to a game shelf.' -ForegroundColor Gray
    Write-Host '   Download covers. Replace icons. Modernize your Games folder.' -ForegroundColor DarkGray
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
}

# ============================================================
#  RUN CONTEXT
# ============================================================

function Get-RunContext {
    <#
        Builds the shared context for a run: settings, API key,
        connection check, target folder, working dirs, overrides,
        saved choices, style, and the artwork category (plan rule 7).
        Returns $null when setup fails or is cancelled.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [bool]$AskCategory = $true,
        [bool]$SkipFolderPrompt = $false,
        [bool]$SkipKeyPrompt = $false
    )

    $settings = Get-Settings -Root $Root

    # Browser mode handles the API key inside the web UI, so we skip
    # the console key prompt and connection test here when asked.
    if ($SkipKeyPrompt) {
        $apiKey = [string]$settings.ApiKey
    } else {
        $apiKey = Get-ApiKey -Root $Root -Settings $settings
        try {
            if (-not (Test-SgdbConnection -ApiKey $apiKey)) {
                Write-Log 'Could not reach SteamGridDB. Check your internet connection or try again later.' 'ERROR'
                return $null
            }
        } catch [System.UnauthorizedAccessException] {
            Write-Log 'Your SteamGridDB API key was rejected (HTTP 401).' 'ERROR'
            $settings.ApiKey = ''
            Save-Settings -Root $Root -Settings $settings
            Write-Log 'The stored key was cleared. Run the tool again and enter a valid key.' 'WARN'
            return $null
        }
        Write-Log 'SteamGridDB connection OK.' 'OK'
    }

    if ($SkipFolderPrompt) {
        # The file-picker mode chooses files directly; folder set later.
        $folder = if (-not [string]::IsNullOrWhiteSpace($settings.LastFolder)) { $settings.LastFolder } else { [Environment]::GetFolderPath('Desktop') }
    } else {
        $folder = Select-ShortcutFolder -Root $Root -Settings $settings
        if ([string]::IsNullOrWhiteSpace($folder)) {
            Write-Log 'No folder selected. Returning to menu.' 'WARN'
            return $null
        }
        Write-Log "Target folder: $folder" 'INFO'
    }

    $iconsDir = Join-Path $Root 'Icons'
    $cacheDir = Join-Path $Root 'Cache'
    foreach ($d in @($iconsDir, $cacheDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }

    $overrides = Get-Overrides -Root $Root
    if ($overrides.Count -gt 0) {
        Write-Log "Loaded $($overrides.Count) manual override(s) from overrides.json" 'INFO'
    }
    $savedChoices = Get-SavedChoices -Root $Root
    if ($savedChoices.Count -gt 0) {
        Write-Log "Loaded $($savedChoices.Count) saved cover choice(s) from choices.json" 'INFO'
    }

    # ---- Artwork category: GRID only ----
    # Game Icons Studio uses square 1:1 grid covers exclusively.
    # Icon and Logo modes were removed to keep the flow simple; the
    # user is never asked to choose a category.
    $category = 'square'
    if ($settings.PreferredArtwork -ne 'square') {
        $settings.PreferredArtwork = 'square'
        Save-Settings -Root $Root -Settings $settings
    }

    return [PSCustomObject]@{
        Root         = $Root
        Settings     = $settings
        ApiKey       = $apiKey
        Folder       = $folder
        IconsDir     = $iconsDir
        CacheDir     = $cacheDir
        Overrides    = $overrides
        SavedChoices = $savedChoices
        ChoicesDirty = $false
        Category     = $category
        TopN         = [Math]::Max(10, [int]$settings.InteractiveTopN)
        Meta         = @{}
        Style        = @{
            CornerRadiusPercent = [int]$settings.RoundedCornerPercent
            BorderWidthPercent  = [int]$settings.BorderWidthPercent
            BorderColor         = [string]$settings.BorderColor
            ShadowEnabled       = [bool]$settings.ShadowEnabled
        }
    }
}

function Get-ScannedShortcuts {
    <#
        Scans the context folder, normalizes names and collects
        per-game metadata (release year from "(2018)" patterns,
        Steam AppID from targets) for the matching engine.
        Returns @{ Shortcuts; Meta } or $null.
    #>
    param([Parameter(Mandatory)]$Ctx)

    Write-Log 'Scanning for .lnk files...' 'INFO'
    $shortcuts = @(Get-Shortcuts -Folder $Ctx.Folder)
    if ($shortcuts.Count -eq 0) {
        Write-Log 'No shortcuts found in the selected folder.' 'WARN'
        return $null
    }
    Write-Log "Found $($shortcuts.Count) shortcut(s)." 'OK'

    $meta = @{}
    foreach ($s in $shortcuts) {
        if ($s.Status -eq 'Failed') { continue }
        $s.NormalizedName = Get-NormalizedGameName -Name $s.Name
        if (-not $meta.ContainsKey($s.NormalizedName)) {
            $meta[$s.NormalizedName] = @{
                Year  = Get-GameYearFromName -Name $s.Name
                AppId = Get-ShortcutSteamAppId -Target $s.Target -Arguments $s.Arguments
            }
        }
    }
    return @{ Shortcuts = $shortcuts; Meta = $meta }
}

# ============================================================
#  RESOLVE ENGINE
# ============================================================

function New-ArtworkResolution {
    <#
        Builds a standard resolution entry for one game.
        DeleteRaw removes stale cached artwork so a newly chosen
        URL is always downloaded fresh.
    #>
    param(
        [Parameter(Mandatory)]$Ctx,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Safe,
        [Parameter(Mandatory)][string]$IcoPath,
        [Parameter(Mandatory)][string]$Url,
        [string]$Kind = 'square',
        [string]$GameName = '',
        [double]$Score = 1.0,
        [bool]$Saved = $false,
        [bool]$DeleteRaw = $true
    )

    $ext = [System.IO.Path]::GetExtension(($Url -split '\?')[0])
    if ([string]::IsNullOrWhiteSpace($ext)) { $ext = '.png' }
    $rawPath = Join-Path $Ctx.CacheDir "$Safe$ext"

    if ($DeleteRaw -and (Test-Path $rawPath)) {
        Remove-Item -Path $rawPath -Force -ErrorAction SilentlyContinue
    }
    if ([string]::IsNullOrWhiteSpace($GameName)) { $GameName = $Name }

    return @{
        IcoPath    = $IcoPath
        ArtworkUrl = $Url
        RawPath    = $rawPath
        Kind       = $Kind
        GameName   = $GameName
        Score      = $Score
        Cached     = $false
        Failed     = $false
        Saved      = $Saved
    }
}

function Resolve-Shortcuts {
    <#
        The matching engine. Per unique game: cached icon ->
        saved manual choice -> override pin -> Steam AppID ->
        year-aware fuzzy match (with confirmation screen when
        ambiguous in Smart/Manual modes) -> covers (interactive
        top-N or automatic best). Returns @{ Resolutions; Pending }.
    #>
    param(
        [Parameter(Mandatory)]$Ctx,
        [Parameter(Mandatory)]$Shortcuts,
        [bool]$Force = $false,
        [bool]$ConfirmMatches = $false,
        [bool]$InteractiveCovers = $false,
        [bool]$RepickSaved = $false
    )

    $resolutions = @{}
    $pending = New-Object System.Collections.Generic.List[object]
    $pendingIndex = 0
    $usePlaceholders = [bool]$Ctx.Settings.PlaceholderCovers
    $minScore = [double]$Ctx.Settings.MinimumMatchScore

    $uniqueNames = @($Shortcuts | Where-Object { $_.Status -ne 'Failed' } |
        ForEach-Object { $_.NormalizedName } | Sort-Object -Unique)
    Write-Log "Unique game names to resolve: $($uniqueNames.Count)" 'INFO'

    $idx = 0
    foreach ($nameRaw in $uniqueNames) {
        $name = [string]$nameRaw
        $idx++
        $safe = Get-SafeFileName -Name $name
        $icoPath = Join-Path $Ctx.IconsDir "$safe.ico"
        $tag = "[$idx/$($uniqueNames.Count)]"

        if (-not $Force -and (Test-Path $icoPath)) {
            $resolutions[$name] = @{ IcoPath = $icoPath; Cached = $true; Failed = $false; GameName = $name; Score = 1.0 }
            Write-Log "$tag '$name' -> cached icon reused." 'DEBUG'
            continue
        }

        # ---- Saved manual choice: the user's pick always wins ----
        if ($Ctx.SavedChoices.ContainsKey($name) -and -not ($InteractiveCovers -and $RepickSaved)) {
            $saved = $Ctx.SavedChoices[$name]
            $savedKind = if ($saved.PSObject.Properties.Name -contains 'Kind' -and $saved.Kind) { [string]$saved.Kind } else { 'square' }
            $savedGame = if ($saved.PSObject.Properties.Name -contains 'GameName' -and $saved.GameName) { [string]$saved.GameName } else { $name }
            $resolutions[$name] = New-ArtworkResolution -Ctx $Ctx -Name $name -Safe $safe -IcoPath $icoPath `
                -Url ([string]$saved.Url) -Kind $savedKind -GameName $savedGame -Score 1.0 -Saved $true -DeleteRaw:$Force
            Write-Log "$tag '$name' -> saved manual choice reused." 'OK'
            continue
        }

        try {
            # ---- Game matching ----
            $gameId = 0
            $matchedName = $null
            $matchScore = 1.0

            if ($Ctx.Overrides.ContainsKey($name)) {
                $gameId = [int]$Ctx.Overrides[$name]
                $matchedName = Get-SgdbGameNameById -ApiKey $Ctx.ApiKey -GameId $gameId
                Write-Log "$tag '$name' -> OVERRIDE pinned to '$matchedName' (ID $gameId)" 'INFO'
            } else {
                $year = 0; $appId = 0
                if ($Ctx.Meta.ContainsKey($name)) {
                    $year = [int]$Ctx.Meta[$name].Year
                    $appId = [int64]$Ctx.Meta[$name].AppId
                }

                $match = Resolve-GameMatch -ApiKey $Ctx.ApiKey -Name $name -Year $year -SteamAppId $appId -MinScore $minScore

                # Auto mode is always silent: take the best match.
                # Hand-fixing happens in the visual Change Icons mode.
                if ($match.GameId -gt 0) {
                    $gameId = $match.GameId
                    $matchedName = $match.GameName
                    $matchScore = $match.Score
                }
            }

            if ($gameId -le 0) {
                if ($usePlaceholders) {
                    $resolutions[$name] = @{ Placeholder = $true; IcoPath = $icoPath; GameName = $name; Failed = $false; Cached = $false }
                    Write-Log "$tag '$name' -> no confident match, placeholder cover will be generated." 'WARN'
                } else {
                    $resolutions[$name] = @{ Failed = $true; Reason = 'No confident match on SteamGridDB' }
                    Write-Log "$tag '$name' -> no confident match, skipping." 'WARN'
                }
                continue
            }

            # ---- Covers: always the best automatic pick ----
            $artworkUrl = $null
            $artworkKind = $null

            if ([string]::IsNullOrWhiteSpace($artworkUrl)) {
                $best = Get-BestArtwork -ApiKey $Ctx.ApiKey -GameId $gameId -Category $Ctx.Category
                if ($null -ne $best) {
                    $artworkUrl = $best.Url
                    $artworkKind = $best.Kind
                }
            }

            if ([string]::IsNullOrWhiteSpace($artworkUrl)) {
                if ($usePlaceholders) {
                    $resolutions[$name] = @{ Placeholder = $true; IcoPath = $icoPath; GameName = $matchedName; Failed = $false; Cached = $false }
                    Write-Log "$tag '$name' -> matched '$matchedName' but no artwork; placeholder cover will be generated." 'WARN'
                } else {
                    $resolutions[$name] = @{ Failed = $true; Reason = 'Match found but no artwork available' }
                    Write-Log "$tag '$name' -> matched '$matchedName' but no artwork found." 'WARN'
                }
                continue
            }

            $resolutions[$name] = New-ArtworkResolution -Ctx $Ctx -Name $name -Safe $safe -IcoPath $icoPath `
                -Url $artworkUrl -Kind $artworkKind -GameName $matchedName -Score $matchScore -DeleteRaw:$Force
            Write-Log "$tag '$name' -> '$matchedName' (score $matchScore, artwork: $artworkKind)" 'OK'
        } catch [System.UnauthorizedAccessException] {
            Write-Log 'API key became invalid mid-run. Aborting search phase.' 'ERROR'
            break
        } catch {
            $resolutions[$name] = @{ Failed = $true; Reason = $_.Exception.Message }
            Write-Log "$tag '$name' -> resolve failed: $($_.Exception.Message)" 'ERROR'
        }
    }

    # Convert the generic List to a plain array so downstream
    # @() and property access never hit the List type-binding bug.
    $pendingArr = @()
    foreach ($entry in $pending) { $pendingArr += $entry }
    return [PSCustomObject]@{ Resolutions = $resolutions; Pending = $pendingArr }
}

# ============================================================
#  COVER SELECTION (browser page)
# ============================================================

function Invoke-CoverSelection {
    param(
        $Ctx,
        $Pending,
        $Resolutions
    )

    # Normalize $Pending to a plain array WITHOUT @() wrapping a
    # generic List (that wrapping threw 'Argument types do not
    # match' on some PowerShell builds). Build the array by hand.
    $items = @()
    if ($null -ne $Pending) {
        foreach ($entry in $Pending) { $items += $entry }
    }
    if ($items.Count -eq 0) { return }

    Write-Host ''
    Write-Log "Opening cover selection page for $($items.Count) game(s)..." 'INFO'
    $htmlPath = New-SelectionPage -Root $Ctx.Root -Pending $items
    try {
        Start-Process -FilePath $htmlPath
    } catch {
        Write-Log "Could not open the browser automatically. Open this file manually: $htmlPath" 'WARN'
    }
    Write-Host ''
    Write-Host '  1. Pick a cover for each game in the browser (top scored is preselected).' -ForegroundColor Cyan
    Write-Host '  2. Press COPY CODE on the page.' -ForegroundColor Cyan
    Write-Host '  3. Paste the code below and press Enter.' -ForegroundColor Cyan
    Write-Host ''
    $choices = Read-SelectionChoices

    foreach ($p in $items) {
        $choice = 1
        # String key + explicit int parsing: avoids the hashtable
        # type-binding mismatch that crashed v5/v5.1 here.
        $idxKey = [string]([int]$p.Index)
        if ($choices.ContainsKey($idxKey)) {
            $parsedChoice = 0
            if ([int]::TryParse([string]$choices[$idxKey], [ref]$parsedChoice)) { $choice = $parsedChoice }
        }
        $candList = @($p.Candidates)
        if ($choice -lt 1 -or $choice -gt $candList.Count) { $choice = 1 }
        $cand = $candList[$choice - 1]

        $pName = [string]$p.Name
        $Resolutions[$pName] = New-ArtworkResolution -Ctx $Ctx -Name $pName -Safe ([string]$p.Safe) -IcoPath ([string]$p.IcoPath) `
            -Url ([string]$cand.Url) -Kind ([string]$p.Kind) -GameName ([string]$p.GameName) -Score ([double]$p.Score) -DeleteRaw $true

        $Ctx.SavedChoices[$pName] = [PSCustomObject]@{
            Url      = [string]$cand.Url
            GameName = [string]$p.GameName
            Kind     = [string]$p.Kind
            PickedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        }
        $Ctx.ChoicesDirty = $true
        Write-Log "Selection: '$($p.Name)' -> cover #$choice" 'OK'
    }

    # Persist picks IMMEDIATELY: an interrupted run never loses them
    if ($Ctx.ChoicesDirty) {
        Save-SavedChoices -Root $Ctx.Root -Choices $Ctx.SavedChoices
        $Ctx.ChoicesDirty = $false
        Write-Log "choices.json written ($($Ctx.SavedChoices.Count) saved choice(s))." 'OK'
    }
}

# ============================================================
#  APPLY PIPELINE (download -> build -> backup -> apply -> report)
# ============================================================

function Invoke-ApplyPipeline {
    param(
        [Parameter(Mandatory)]$Ctx,
        [Parameter(Mandatory)]$Shortcuts,
        [Parameter(Mandatory)]$Resolutions,
        [bool]$Force = $false,
        [TimeSpan]$ResolveDuration = [TimeSpan]::Zero
    )

    $swTotal = [System.Diagnostics.Stopwatch]::StartNew()
    $phaseTimes = New-Object System.Collections.Generic.List[object]
    if ($ResolveDuration.TotalMilliseconds -gt 0) {
        $phaseTimes.Add([PSCustomObject]@{ Name = 'Scan + match'; Span = $ResolveDuration })
    }
    $usePlaceholders = [bool]$Ctx.Settings.PlaceholderCovers
    $style = $Ctx.Style

    # ---------- Build the download queue ----------
    $downloadQueue = New-Object System.Collections.Generic.List[object]
    foreach ($key in @($Resolutions.Keys)) {
        $r = $Resolutions[$key]
        if ($r.Failed -or $r.Cached -or $r.Placeholder) { continue }
        if ([string]::IsNullOrWhiteSpace($r.ArtworkUrl) -or [string]::IsNullOrWhiteSpace($r.RawPath)) { continue }
        if (-not (Test-Path $r.RawPath)) {
            $downloadQueue.Add([PSCustomObject]@{ Url = $r.ArtworkUrl; Dest = $r.RawPath })
        }
    }

    # ---------- PHASE 2/5: Download (hard-timeout HttpClient) ----------
    $swPhase = [System.Diagnostics.Stopwatch]::StartNew()
    if ($downloadQueue.Count -gt 0) {
        Show-PhaseBanner "PHASE 2/5: DOWNLOAD ($($downloadQueue.Count) covers)"

        $throttle = [Math]::Max(1, [int]$Ctx.Settings.ParallelDownloads)
        $dlDone = 0
        $dlTotal = $downloadQueue.Count

        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $downloadResults = @($downloadQueue | ForEach-Object -ThrottleLimit $throttle -Parallel {
                # HttpClient with a HARD timeout covering the WHOLE
                # transfer (Invoke-WebRequest -TimeoutSec does not,
                # which froze v4 runs on stalled CDN connections).
                $item = $_
                $ok = $false; $err = $null; $attempts = 0
                while (-not $ok -and $attempts -lt 3) {
                    $attempts++
                    $client = $null
                    try {
                        if (Test-Path $item.Dest) { $ok = $true; break }
                        $client = [System.Net.Http.HttpClient]::new()
                        $client.Timeout = [TimeSpan]::FromSeconds(45)
                        $null = $client.DefaultRequestHeaders.UserAgent.TryParseAdd('Mozilla/5.0 (Windows NT 10.0; Win64; x64) SGDB-Icon-Updater/5.0')
                        $bytes = $client.GetByteArrayAsync($item.Url).GetAwaiter().GetResult()
                        if ($null -eq $bytes -or $bytes.Length -lt 100) { throw 'Empty or invalid response' }
                        [System.IO.File]::WriteAllBytes($item.Dest, $bytes)
                        $ok = $true
                    } catch {
                        $err = $_.Exception.Message
                        Start-Sleep -Milliseconds (350 * $attempts)
                    } finally {
                        if ($client) { $client.Dispose() }
                    }
                }
                [PSCustomObject]@{ Dest = $item.Dest; Ok = $ok; Error = $err }
            } | ForEach-Object {
                $dlDone++
                Show-InlineProgress -Current $dlDone -Total $dlTotal -Label 'Downloading' -Item ([System.IO.Path]::GetFileNameWithoutExtension($_.Dest))
                $_
            })
        } else {
            try { Add-Type -AssemblyName System.Net.Http -ErrorAction Stop } catch { }
            $downloadResults = @(foreach ($item in $downloadQueue) {
                $ok = $false; $err = $null; $attempts = 0
                while (-not $ok -and $attempts -lt 3) {
                    $attempts++
                    $client = $null
                    try {
                        if (Test-Path $item.Dest) { $ok = $true; break }
                        $client = [System.Net.Http.HttpClient]::new()
                        $client.Timeout = [TimeSpan]::FromSeconds(45)
                        $null = $client.DefaultRequestHeaders.UserAgent.TryParseAdd('Mozilla/5.0 (Windows NT 10.0; Win64; x64) SGDB-Icon-Updater/5.0')
                        $bytes = $client.GetByteArrayAsync($item.Url).GetAwaiter().GetResult()
                        if ($null -eq $bytes -or $bytes.Length -lt 100) { throw 'Empty or invalid response' }
                        [System.IO.File]::WriteAllBytes($item.Dest, $bytes)
                        $ok = $true
                    } catch {
                        $err = $_.Exception.Message
                        Start-Sleep -Milliseconds (350 * $attempts)
                    } finally {
                        if ($client) { $client.Dispose() }
                    }
                }
                $dlDone++
                Show-InlineProgress -Current $dlDone -Total $dlTotal -Label 'Downloading' -Item ([System.IO.Path]::GetFileNameWithoutExtension($item.Dest))
                [PSCustomObject]@{ Dest = $item.Dest; Ok = $ok; Error = $err }
            })
        }
        Complete-InlineProgress

        # ---- Failures: log, drop dead saved choices, placeholder rescue ----
        $failedDownloads = @($downloadResults | Where-Object { -not $_.Ok })
        foreach ($f in $failedDownloads) {
            Write-Log "Download failed: $($f.Dest) ($($f.Error))" 'ERROR'
            foreach ($key in @($Resolutions.Keys)) {
                $r = $Resolutions[$key]
                if (-not $r.Failed -and -not $r.Cached -and -not $r.Placeholder -and $r.RawPath -eq $f.Dest) {
                    if ($r.Saved -and $Ctx.SavedChoices.ContainsKey($key)) {
                        $Ctx.SavedChoices.Remove($key)
                        $Ctx.ChoicesDirty = $true
                        Write-Log "Saved choice for '$key' is no longer downloadable; removed from choices.json. Re-pick it later." 'WARN'
                    }
                    if ($usePlaceholders) {
                        $Resolutions[$key] = @{ Placeholder = $true; IcoPath = $r.IcoPath; GameName = $key; Failed = $false; Cached = $false }
                    } else {
                        $r.Failed = $true
                        $r.Reason = "Download failed: $($f.Error)"
                    }
                }
            }
        }
        Write-Log "Downloads complete. OK: $(@($downloadResults).Count - $failedDownloads.Count), Failed: $($failedDownloads.Count)" 'INFO'
    }
    $phaseTimes.Add([PSCustomObject]@{ Name = 'Download'; Span = $swPhase.Elapsed })

    if ($Ctx.ChoicesDirty) {
        Save-SavedChoices -Root $Ctx.Root -Choices $Ctx.SavedChoices
        $Ctx.ChoicesDirty = $false
        Write-Log 'choices.json updated.' 'INFO'
    }

    # ---------- PHASE 3/5: Build ICO files ----------
    $swPhase = [System.Diagnostics.Stopwatch]::StartNew()
    $buildKeys = @($Resolutions.Keys | Where-Object { -not $Resolutions[$_].Failed -and -not $Resolutions[$_].Cached })
    Show-PhaseBanner "PHASE 3/5: BUILD ICONS ($($buildKeys.Count) icons)"
    Write-Log "Building .ico files (16-256 px, rounded: $($style.CornerRadiusPercent)%, border: $($style.BorderWidthPercent)%, shadow: $($style.ShadowEnabled))" 'INFO' $true

    $buildDone = 0
    foreach ($name in $buildKeys) {
        $r = $Resolutions[$name]
        $buildDone++
        Show-InlineProgress -Current $buildDone -Total $buildKeys.Count -Label 'Building' -Item $name

        try {
            $contain = ($r.Kind -eq 'logo')
            if ($r.Placeholder) {
                $safe = Get-SafeFileName -Name $name
                $pngPath = Join-Path $Ctx.CacheDir "$safe`_placeholder.png"
                $null = New-PlaceholderCover -GameName $r.GameName -OutputPath $pngPath
                $null = ConvertTo-Ico -SourcePath $pngPath -OutputPath $r.IcoPath `
                    -CornerRadiusPercent $style.CornerRadiusPercent `
                    -BorderWidthPercent $style.BorderWidthPercent `
                    -BorderColor $style.BorderColor `
                    -ShadowEnabled $style.ShadowEnabled
                Write-Log "Placeholder cover built: $([System.IO.Path]::GetFileName($r.IcoPath))" 'DEBUG' $true
            } else {
                $null = ConvertTo-Ico -SourcePath $r.RawPath -OutputPath $r.IcoPath `
                    -CornerRadiusPercent $style.CornerRadiusPercent `
                    -BorderWidthPercent $style.BorderWidthPercent `
                    -BorderColor $style.BorderColor `
                    -ShadowEnabled $style.ShadowEnabled `
                    -Contain $contain
                Write-Log "ICO ready: $([System.IO.Path]::GetFileName($r.IcoPath))" 'DEBUG' $true
            }
        } catch {
            $r.Failed = $true
            $r.Reason = "ICO conversion failed: $($_.Exception.Message)"
            Write-Log "ICO conversion failed for '$name': $($_.Exception.Message)" 'ERROR' $true
        }
    }
    Complete-InlineProgress
    $phaseTimes.Add([PSCustomObject]@{ Name = 'Build icons'; Span = $swPhase.Elapsed })

    # ---------- PHASE 4/5: Apply ----------
    $swPhase = [System.Diagnostics.Stopwatch]::StartNew()
    Show-PhaseBanner "PHASE 4/5: APPLY ($(@($Shortcuts).Count) shortcuts)"

    $applyDone = 0
    foreach ($s in $Shortcuts) {
        $applyDone++
        Show-InlineProgress -Current $applyDone -Total @($Shortcuts).Count -Label 'Applying' -Item $s.Name
        if ($s.Status -eq 'Failed') { continue }

        $r = $Resolutions[[string]$s.NormalizedName]
        if ($null -eq $r -or $r.Failed) {
            $s.Status = 'Skipped'
            $s.Detail = if ($r) { $r.Reason } else { 'Unresolved' }
            continue
        }

        try {
            Set-ShortcutIcon -ShortcutPath $s.Path -IcoPath $r.IcoPath

            $s.Status = 'Updated'
            $s.Detail = if ($r.Placeholder) { '-> placeholder cover' } else { "-> $([System.IO.Path]::GetFileName($r.IcoPath))" }
            Write-Log "Updated: $($s.Name)" 'OK' $true
        } catch {
            $s.Status = 'Failed'
            $s.Detail = $_.Exception.Message
            Write-Log "Failed to update '$($s.Name)': $($_.Exception.Message)" 'ERROR' $true
        }
    }
    Complete-InlineProgress
    $phaseTimes.Add([PSCustomObject]@{ Name = 'Apply'; Span = $swPhase.Elapsed })

    # ---------- PHASE 5/5: Refresh + report ----------
    Show-PhaseBanner 'PHASE 5/5: REFRESH + REPORT'
    Update-ExplorerIcons

    $total       = @($Shortcuts).Count
    $updated     = @($Shortcuts | Where-Object { $_.Status -eq 'Updated' }).Count
    $placeholder = @($Shortcuts | Where-Object { $_.Status -eq 'Updated' -and $_.Detail -eq '-> placeholder cover' }).Count
    $skipped     = @($Shortcuts | Where-Object { $_.Status -eq 'Skipped' }).Count
    $failed      = @($Shortcuts | Where-Object { $_.Status -eq 'Failed' }).Count
    $matched     = $updated - $placeholder

    $swTotal.Stop()
    $maxCount = [Math]::Max(1, $total)

    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
    Write-Host '   REPORT' -ForegroundColor Cyan
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
    Write-Host "   Total scanned : $total   |   Total time: $(Format-Duration $swTotal.Elapsed)"
    Write-Host ''
    Show-CountBar -Label 'Matched'     -Value $matched     -Max $maxCount -Color Cyan
    Show-CountBar -Label 'Updated'     -Value $updated     -Max $maxCount -Color Green
    Show-CountBar -Label 'Placeholder' -Value $placeholder -Max $maxCount -Color Magenta
    Show-CountBar -Label 'Skipped'     -Value $skipped     -Max $maxCount -Color Yellow
    Show-CountBar -Label 'Failed'      -Value $failed      -Max $maxCount -Color Red
    Write-Host ''
    foreach ($phase in $phaseTimes) {
        Write-Host ("   {0,-16} {1}" -f $phase.Name, (Format-Duration $phase.Span)) -ForegroundColor DarkGray
    }
    Write-Host '  ============================================================' -ForegroundColor DarkCyan

    if ($skipped -gt 0 -or $failed -gt 0) {
        Write-Host ''
        Write-Host '   Details for skipped / failed items:' -ForegroundColor DarkGray
        foreach ($s in $Shortcuts | Where-Object { $_.Status -in @('Skipped','Failed') }) {
            Write-Host "    - [$($s.Status)] $($s.Name): $($s.Detail)" -ForegroundColor DarkGray
        }
    }

    Write-Log "Report - Total: $total, Matched: $matched, Updated: $updated, Placeholder: $placeholder, Skipped: $skipped, Failed: $failed" 'INFO' $true
}

# ============================================================
#  UPDATE RUN (Full Auto / Smart Auto / Manual / Rebuild)
# ============================================================

function Invoke-UpdateRun {
    param(
        [Parameter(Mandatory)][string]$Root,
        [ValidateSet('auto')][string]$Mode = 'auto'
    )

    $ctx = Get-RunContext -Root $Root -AskCategory $true
    if ($null -eq $ctx) { return }

    $scan = Get-ScannedShortcuts -Ctx $ctx
    if ($null -eq $scan) { return }
    $ctx.Meta = $scan.Meta
    $shortcuts = $scan.Shortcuts

    # Optional rebuild of cached icons with current settings
    $force = $false
    $existingIcons = @(Get-ChildItem -Path $ctx.IconsDir -Filter '*.ico' -File -ErrorAction SilentlyContinue)
    if ($existingIcons.Count -gt 0) {
        Write-Host ''
        Write-Host "  $($existingIcons.Count) cached icon(s) found from previous runs." -ForegroundColor Cyan
        if (Read-YesNoKey -Prompt '  Rebuild ALL icons with the current settings?') {
            $force = $true
            Write-Log 'Force rebuild enabled.' 'INFO'
        }
    }

    Write-Log 'Mode: AUTO (whole folder, best match + best cover, no questions)' 'INFO'

    Show-PhaseBanner 'PHASE 1/5: SCAN + MATCH'
    $swResolve = [System.Diagnostics.Stopwatch]::StartNew()
    # Silent: never confirm matches, never interactive covers. To
    # hand-fix specific icons, use menu option [2] Change Icons.
    $result = Resolve-Shortcuts -Ctx $ctx -Shortcuts $shortcuts -Force $force `
        -ConfirmMatches $false -InteractiveCovers $false -RepickSaved $false
    $swResolve.Stop()

    Invoke-ApplyPipeline -Ctx $ctx -Shortcuts $shortcuts -Resolutions $result.Resolutions -Force $force -ResolveDuration $swResolve.Elapsed

    # To fix specific icons afterwards, use menu option [2] Change Icons.
}

function Write-ErrorDetails {
    <#
        Pinpoint crash reporter: exception type, exact file, line
        number, offending line text, and the full stack trace -
        printed to BOTH console and log.
    #>
    param(
        [Parameter(Mandatory)]$ErrorRecord,
        [string]$Context = 'Unhandled'
    )
    try {
        Write-Log "$Context error: $($ErrorRecord.Exception.GetType().FullName): $($ErrorRecord.Exception.Message)" 'ERROR'
        $inv = $ErrorRecord.InvocationInfo
        if ($null -ne $inv -and $inv.ScriptLineNumber -gt 0) {
            $file = [System.IO.Path]::GetFileName([string]$inv.ScriptName)
            Write-Log ("Location: {0}:{1}  ->  {2}" -f $file, $inv.ScriptLineNumber, ([string]$inv.Line).Trim()) 'ERROR'
        }
        if ($ErrorRecord.ScriptStackTrace) {
            Write-Log "Stack trace:" 'ERROR'
            foreach ($line in ($ErrorRecord.ScriptStackTrace -split "`r?`n")) {
                Write-Log "  $line" 'ERROR'
            }
        }
    } catch {
        Write-Host "FATAL (reporter failed): $($ErrorRecord.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================================
#  MAIN MENU
# ============================================================

function Invoke-MainMenu {
    Show-Banner
    Initialize-Logger -Root $Root

    while ($true) {
        Write-Host ''
        Write-Host '   [1] Studio (Browser)  - do everything in a guided browser app  [recommended]' -ForegroundColor White
        Write-Host '   [2] Auto (CMD)        - scan the whole folder, best match + best cover' -ForegroundColor Gray
        Write-Host '   [3] Change Icons (CMD)- pick specific shortcuts, match game + cover visually' -ForegroundColor Gray
        Write-Host '   [5] Cache management' -ForegroundColor DarkGray
        Write-Host '   [0] Exit' -ForegroundColor DarkGray
        $choice = Read-KeyChoice -Prompt '  Choose [Enter = 1]:' -Allowed @('1','2','3','5','0') -Default '1'

        try {
            switch ($choice) {
                '1' { Invoke-BrowserMode -Root $Root }
                '2' { Invoke-UpdateRun -Root $Root -Mode 'auto' }
                '3' { Invoke-ChangeIconsMode -Root $Root }
                '5' { Invoke-CacheMenu -Root $Root }
                '0' {
                    Write-Log 'Session finished.' 'INFO' $true
                    return
                }
                default { }
            }
        } catch [System.UnauthorizedAccessException] {
            Write-Log 'SteamGridDB API key was rejected during the operation. Check it and try again.' 'ERROR'
        } catch {
            # Pinpoint reporter: names the file + line so any future
            # crash is diagnosable at a glance. The menu keeps running.
            Write-ErrorDetails -ErrorRecord $_ -Context 'Operation'
            Write-Host ''
            Write-Host '  Something went wrong, but your pins and choices are saved.' -ForegroundColor Yellow
            Write-Host '  The details above (file + line) pinpoint the cause. Back to menu.' -ForegroundColor Yellow
        }
    }
}

# ---- Entry point: browser-first, never crash ----
try {
    Show-Banner
    Initialize-Logger -Root $Root
    Invoke-BrowserMode -Root $Root
} catch {
    Write-ErrorDetails -ErrorRecord $_ -Context 'Unhandled'
    Write-Host ''
    Write-Host '  Something went wrong starting the studio. The details above' -ForegroundColor Yellow
    Write-Host '  (file + line) pinpoint the cause.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Press Enter to close.' -ForegroundColor Gray
    [void](Read-Host)
}
