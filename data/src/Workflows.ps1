# ============================================================
#  Workflows.ps1 (v5.5) - Change Icons mode
#  Native file picker -> visual browser page where each picked
#  shortcut lists its candidate GAMES, each game showing its best
#  covers. One click selects game + cover together.
# ============================================================

function Invoke-ChangeIconsMode {
    <#
        Menu [3] Change Icons:
        1. Native Windows file picker (large icons, Ctrl-multi).
        2. For each picked shortcut, fetch the top candidate games,
           each with its best covers, and show them on ONE browser
           page. The user clicks the right game's preferred cover.
        3. Apply only those shortcuts. Pins the chosen game to
           overrides.json and the cover to choices.json.
    #>
    param([Parameter(Mandatory)][string]$Root)

    $ctx = Get-RunContext -Root $Root -AskCategory $true -SkipFolderPrompt $true
    if ($null -eq $ctx) { return }

    Write-Host ''
    Write-Host '  Opening the file picker...' -ForegroundColor Cyan
    Write-Host '  Tip: switch the view to Large/Extra Large icons to see covers,' -ForegroundColor DarkGray
    Write-Host '  then Ctrl+click every shortcut you want to change.' -ForegroundColor DarkGray

    $initial = if (-not [string]::IsNullOrWhiteSpace($ctx.Settings.LastFolder)) { $ctx.Settings.LastFolder } else { [Environment]::GetFolderPath('Desktop') }
    $files = @(Select-ShortcutFiles -InitialFolder $initial)

    if ($files.Count -eq 0) {
        Write-Log 'No files selected. Returning to menu.' 'INFO'
        return
    }
    Write-Log "Selected $($files.Count) shortcut(s) to change." 'OK'

    try {
        $folder = Split-Path -Parent $files[0]
        if (Test-Path $folder) {
            $ctx.Folder = $folder
            $ctx.Settings.LastFolder = $folder
            Save-Settings -Root $Root -Settings $ctx.Settings
        }
    } catch { }

    $shortcuts = @(Get-ShortcutsFromPaths -Paths $files)
    if ($shortcuts.Count -eq 0) {
        Write-Log 'None of the selected files were readable shortcuts.' 'WARN'
        return
    }
    foreach ($s in $shortcuts) {
        if ($s.Status -ne 'Failed') { $s.NormalizedName = Get-NormalizedGameName -Name $s.Name }
    }

    Invoke-VisualMatchRound -Ctx $ctx -Shortcuts $shortcuts

    while ($true) {
        Write-Host ''
        if (-not (Read-YesNoKey -Prompt '  Change more of these icons again?')) { break }
        foreach ($s in $shortcuts) { if ($s.Status -ne 'Failed') { $s.Status = 'Pending'; $s.Detail = '' } }
        Invoke-VisualMatchRound -Ctx $ctx -Shortcuts $shortcuts
    }
}

function Invoke-VisualMatchRound {
    <#
        One round: build candidate games + covers per shortcut,
        open the visual game-match page, read the code, resolve each
        shortcut to the chosen game+cover, then apply.
    #>
    param(
        [Parameter(Mandatory)]$Ctx,
        [Parameter(Mandatory)]$Shortcuts
    )

    Show-PhaseBanner 'PHASE 1/5: BUILD CANDIDATES'
    $swResolve = [System.Diagnostics.Stopwatch]::StartNew()

    # unique name -> sections (candidate games, each with covers)
    $pending = New-Object System.Collections.Generic.List[object]
    $pendingIndex = 0
    $nameToPending = @{}

    $uniqueNames = @($Shortcuts | Where-Object { $_.Status -ne 'Failed' } |
        ForEach-Object { [string]$_.NormalizedName } | Sort-Object -Unique)

    $idx = 0
    foreach ($name in $uniqueNames) {
        $idx++
        Show-InlineProgress -Current $idx -Total $uniqueNames.Count -Label 'Searching' -Item $name
        try {
            $sections = @(Get-GameMatchSections -ApiKey $Ctx.ApiKey -Query $name -Category $Ctx.Category -MaxGames 5 -CoversPerGame $Ctx.TopN)
            if ($sections.Count -eq 0) {
                Write-Log "'$name' -> no artwork in any candidate game; will use placeholder." 'WARN' $true
                continue
            }
            $pendingIndex++
            $safe = Get-SafeFileName -Name $name
            $entry = [PSCustomObject]@{
                Index    = $pendingIndex
                Name     = $name
                Safe     = $safe
                IcoPath  = (Join-Path $Ctx.IconsDir "$safe.ico")
                Sections = $sections
            }
            $pending.Add($entry)
            $nameToPending[[string]$name] = $entry
        } catch [System.UnauthorizedAccessException] {
            Write-Log 'API key became invalid mid-run. Aborting.' 'ERROR'
            break
        } catch {
            Write-Log "Candidate search failed for '$name': $($_.Exception.Message)" 'ERROR' $true
        }
    }
    Complete-InlineProgress
    $swResolve.Stop()

    $pendingArr = @()
    foreach ($e in $pending) { $pendingArr += $e }

    if ($pendingArr.Count -eq 0) {
        Write-Log 'No candidates found for the selected shortcuts.' 'WARN'
        return
    }

    # ---- Open visual game-match page ----
    Write-Host ''
    Write-Log "Opening the visual matcher for $($pendingArr.Count) game(s)..." 'INFO'
    $htmlPath = New-GameMatchPage -Root $Ctx.Root -Pending $pendingArr
    try { Start-Process -FilePath $htmlPath } catch {
        Write-Log "Could not open the browser automatically. Open this file manually: $htmlPath" 'WARN'
    }
    Write-Host ''
    Write-Host '  1. For each shortcut, click the cover that is BOTH the right game' -ForegroundColor Cyan
    Write-Host '     and the look you want.' -ForegroundColor Cyan
    Write-Host '  2. Press COPY CODE on the page.' -ForegroundColor Cyan
    Write-Host '  3. Paste the code below and press Enter.' -ForegroundColor Cyan
    Write-Host ''
    $choices = Read-GameMatchChoices

    # ---- Resolve each unique name to chosen game + cover ----
    $resolutions = @{}
    foreach ($entry in $pendingArr) {
        $key = [string]$entry.Index
        $sectionList = @($entry.Sections)

        $gi = 1; $ci = 1
        if ($choices.ContainsKey($key)) {
            $sel = $choices[$key]
            $gi = [int]$sel.Game
            $ci = [int]$sel.Cover
        }
        if ($gi -lt 1 -or $gi -gt $sectionList.Count) { $gi = 1 }
        $section = $sectionList[$gi - 1]
        $coverList = @($section.Covers)
        if ($ci -lt 1 -or $ci -gt $coverList.Count) { $ci = 1 }
        $cover = $coverList[$ci - 1]

        $nm = [string]$entry.Name
        $resolutions[$nm] = New-ArtworkResolution -Ctx $Ctx -Name $nm -Safe ([string]$entry.Safe) -IcoPath ([string]$entry.IcoPath) `
            -Url ([string]$cover.Url) -Kind ([string]$Ctx.Category) -GameName ([string]$section.GameName) -Score 1.0 -DeleteRaw $true

        # Pin both the game (overrides) and the cover (choices)
        $Ctx.Overrides[$nm] = [int]$section.GameId
        $Ctx.SavedChoices[$nm] = [PSCustomObject]@{
            Url      = [string]$cover.Url
            GameName = [string]$section.GameName
            Kind     = [string]$Ctx.Category
            PickedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        }
        Write-Log "Matched '$nm' -> '$($section.GameName)' (cover #$ci)" 'OK'
    }
    Save-Overrides -Root $Ctx.Root -Overrides $Ctx.Overrides
    Save-SavedChoices -Root $Ctx.Root -Choices $Ctx.SavedChoices

    Invoke-ApplyPipeline -Ctx $Ctx -Shortcuts $Shortcuts -Resolutions $resolutions -Force $true -ResolveDuration $swResolve.Elapsed
}
