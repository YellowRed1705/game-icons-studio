# ============================================================
#  Settings.ps1 - settings.json management + folder picker
# ============================================================

function Get-DefaultSettings {
    [PSCustomObject]@{
        ApiKey               = ''
        LastFolder           = ''
        PreferredArtwork     = 'square'   # square | icon | grid | hero
        ParallelDownloads    = 6
        MinimumMatchScore    = 0.55
        RoundedCornerPercent = 14         # 0 disables rounded corners
        BorderWidthPercent   = 0          # 0 disables the border stroke
        BorderColor          = '#FFFFFF'
        ShadowEnabled        = $false     # soft drop shadow behind covers
        PlaceholderCovers    = $true      # auto-generate covers when no artwork exists
        InteractiveSelection = $false     # choose covers in the browser (top N per game)
        InteractiveTopN      = 10
    }
}

function Get-Overrides {
    <#
        Loads overrides.json: a map of game name -> SteamGridDB game ID
        that pins a specific game when fuzzy matching picks the wrong one.
        Keys starting with an underscore are ignored (documentation keys).
        Returns a case-insensitive hashtable name -> [int]gameId.
    #>
    param([Parameter(Mandatory)][string]$Root)

    $path = Join-Path $Root 'overrides.json'
    $map = @{}

    if (-not (Test-Path $path)) {
        $template = New-Object PSObject
        $template | Add-Member -MemberType NoteProperty -Name '_readme'  -Value 'Pin a game name to a SteamGridDB game ID when auto-matching gets it wrong. Find the ID in the game page URL on steamgriddb.com.'
        $template | Add-Member -MemberType NoteProperty -Name '_example' -Value 'Add entries like:  "Moonsigil Atlas": 5395423'
        try {
            $template | ConvertTo-Json | Set-Content -Path $path -Encoding UTF8
        } catch { }
        return $map
    }

    try {
        $raw = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $raw.PSObject.Properties) {
            if ($prop.Name.StartsWith('_')) { continue }
            $id = 0
            if ([int]::TryParse([string]$prop.Value, [ref]$id) -and $id -gt 0) {
                $map[$prop.Name] = $id
            }
        }
    } catch {
        Write-Log "overrides.json unreadable: $($_.Exception.Message)" 'WARN'
    }
    return $map
}

function Get-Settings {
    param([Parameter(Mandatory)][string]$Root)

    $path = Join-Path $Root 'settings.json'
    $defaults = Get-DefaultSettings

    if (-not (Test-Path $path)) {
        Save-Settings -Root $Root -Settings $defaults
        return $defaults
    }

    try {
        $raw = Get-Content -Path $path -Raw -Encoding UTF8
        $loaded = $raw | ConvertFrom-Json
    } catch {
        Write-Log "settings.json is corrupt, recreating with defaults. ($($_.Exception.Message))" 'WARN'
        Save-Settings -Root $Root -Settings $defaults
        return $defaults
    }

    # Merge: make sure every expected property exists
    foreach ($prop in $defaults.PSObject.Properties) {
        if (-not ($loaded.PSObject.Properties.Name -contains $prop.Name)) {
            $loaded | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
        }
    }
    return $loaded
}

function Save-Settings {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Settings
    )
    $path = Join-Path $Root 'settings.json'
    try {
        $Settings | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
    } catch {
        Write-Log "Failed to save settings.json: $($_.Exception.Message)" 'ERROR'
    }
}

function Get-ApiKey {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Settings
    )

    if (-not [string]::IsNullOrWhiteSpace($Settings.ApiKey)) {
        return $Settings.ApiKey
    }

    Write-Host ''
    Write-Host '  A SteamGridDB API key is required (one-time setup).' -ForegroundColor Cyan
    Write-Host '  Get yours for free at: https://www.steamgriddb.com/profile/preferences/api' -ForegroundColor Cyan
    Write-Host ''

    $key = ''
    while ([string]::IsNullOrWhiteSpace($key)) {
        $key = Read-Host '  Paste your SteamGridDB API key'
        $key = $key.Trim()
    }

    $Settings.ApiKey = $key
    Save-Settings -Root $Root -Settings $Settings
    Write-Log 'API key saved to settings.json' 'OK'
    return $key
}

function Select-ShortcutFolder {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Settings
    )

    # Offer to reuse the remembered folder first
    if (-not [string]::IsNullOrWhiteSpace($Settings.LastFolder) -and (Test-Path $Settings.LastFolder)) {
        Write-Host ''
        Write-Host "  Last used folder: $($Settings.LastFolder)" -ForegroundColor Cyan
        if (Read-YesNoKey -Prompt '  Use this folder again?' -DefaultYes $true) {
            return $Settings.LastFolder
        }
    }

    Write-Host ''
    Write-Host '  Select the folder that contains your game shortcuts (.lnk)...' -ForegroundColor Cyan

    $selected = $null
    try {
        # Native Windows Shell folder browser (no WinForms / no WPF)
        # Options: 0x1 = return only filesystem dirs, 0x10 = show edit box
        $shell = New-Object -ComObject Shell.Application
        $browse = $shell.BrowseForFolder(0, 'Select your shortcuts folder', 0x11, 0)
        if ($null -ne $browse) {
            $selected = $browse.Self.Path
        }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    } catch {
        Write-Log "Folder dialog failed: $($_.Exception.Message)" 'WARN'
    }

    # Fallback: manual input (also covers virtual shell locations)
    if ([string]::IsNullOrWhiteSpace($selected) -or -not (Test-Path $selected)) {
        Write-Host ''
        $typed = Read-Host '  No valid folder selected. Type a folder path (or press Enter to cancel)'
        if (-not [string]::IsNullOrWhiteSpace($typed) -and (Test-Path $typed.Trim())) {
            $selected = $typed.Trim()
        } else {
            return $null
        }
    }

    $Settings.LastFolder = $selected
    Save-Settings -Root $Root -Settings $Settings
    return $selected
}

function Get-SavedChoices {
    <#
        Loads choices.json: covers the user picked in MANUAL mode.
        Map of normalized game name -> @{ Url; GameName; PickedAt }.
        Saved choices always win over automatic scoring on rebuilds.
    #>
    param([Parameter(Mandatory)][string]$Root)

    $path = Join-Path $Root 'choices.json'
    $map = @{}
    if (-not (Test-Path $path)) { return $map }

    try {
        $raw = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $raw.PSObject.Properties) {
            if ($null -ne $prop.Value -and $prop.Value.PSObject.Properties.Name -contains 'Url' -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value.Url)) {
                $map[$prop.Name] = $prop.Value
            }
        }
    } catch {
        Write-Log "choices.json unreadable: $($_.Exception.Message)" 'WARN'
    }
    return $map
}

function Save-SavedChoices {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][hashtable]$Choices
    )
    $path = Join-Path $Root 'choices.json'
    try {
        $obj = New-Object PSObject
        foreach ($key in @($Choices.Keys | Sort-Object)) {
            $obj | Add-Member -MemberType NoteProperty -Name ([string]$key) -Value $Choices[$key] -Force
        }
        $json = ConvertTo-Json -InputObject $obj -Depth 4
        [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($true)))
    } catch {
        Write-Log "Failed to save choices.json: $($_.Exception.GetType().Name): $($_.Exception.Message)" 'WARN'
    }
}


function Save-Overrides {
    <#
        Writes the full override map back to overrides.json.
        Called automatically when the user confirms a game in the
        selection screen, so the fix sticks for every future run.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][hashtable]$Overrides
    )
    $path = Join-Path $Root 'overrides.json'
    try {
        # Built via Add-Member on a PSObject: avoids the OrderedDictionary
        # dynamic-binding edge case behind 'Argument types do not match'.
        $obj = New-Object PSObject
        $obj | Add-Member -MemberType NoteProperty -Name '_readme' -Value 'Pin a game name to a SteamGridDB game ID when auto-matching gets it wrong. Entries here always win over automatic matching.'
        foreach ($key in @($Overrides.Keys | Sort-Object)) {
            $obj | Add-Member -MemberType NoteProperty -Name ([string]$key) -Value ([int]$Overrides[$key]) -Force
        }
        $json = ConvertTo-Json -InputObject $obj -Depth 4
        [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($true)))
    } catch {
        Write-Log "Failed to save overrides.json: $($_.Exception.Message)" 'WARN'
    }
}

function Select-FolderForeground {
    <#
        Opens the native Windows folder browser and forces it to the
        FOREGROUND so it never hides behind the console window. Used
        by the browser mode, where the user is looking at the browser
        and must not have to hunt for the dialog in the taskbar.

        Returns the selected path, or '' if cancelled.
    #>
    param([string]$InitialPath = '')

    $selected = ''

    # Ensure a foreground-capable owner handle and bring dialogs forward.
    $sig = @'
using System;
using System.Runtime.InteropServices;
public static class Win32Fg {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@
    try {
        if (-not ([System.Management.Automation.PSTypeName]'Win32Fg').Type) {
            Add-Type -TypeDefinition $sig -ErrorAction Stop
        }
    } catch { }

    try {
        $shell = New-Object -ComObject Shell.Application
        # Briefly flash the console to the foreground so the modal
        # folder dialog it spawns inherits foreground focus.
        try {
            $console = [Win32Fg]::GetConsoleWindow()
            if ($console -ne [IntPtr]::Zero) {
                [Win32Fg]::ShowWindow($console, 5) | Out-Null   # SW_SHOW
                [Win32Fg]::SetForegroundWindow($console) | Out-Null
            }
        } catch { }

        # 0x11 = BIF_RETURNONLYFSDIRS (0x1) + BIF_EDITBOX (0x10)
        $browse = $shell.BrowseForFolder([int]([Win32Fg]::GetConsoleWindow()), 'Select your game shortcuts folder', 0x11, 0)
        if ($null -ne $browse) { $selected = [string]$browse.Self.Path }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    } catch {
        Write-Log "Foreground folder dialog failed: $($_.Exception.Message)" 'WARN'
    }

    if ([string]::IsNullOrWhiteSpace($selected) -or -not (Test-Path $selected)) { return '' }
    return $selected
}

function Get-KnownGamesPath {
    param([Parameter(Mandatory)][string]$Root)
    return (Join-Path $Root 'knownGames.json')
}

function Get-KnownGames {
    <#
        Returns the remembered game-name list for a given folder (keyed
        by folder path). Used to detect newly added games on re-scan.
        Returns @{ map = <PSObject keyed by folder> }.
    #>
    param([Parameter(Mandatory)][string]$Root)

    $path = Get-KnownGamesPath -Root $Root
    if (-not (Test-Path $path)) { return @{} }
    try {
        $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json
        $h = @{}
        foreach ($p in $raw.PSObject.Properties) { $h[$p.Name] = @($p.Value) }
        return $h
    } catch {
        return @{}
    }
}

function Save-KnownGames {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][hashtable]$Map
    )
    $path = Get-KnownGamesPath -Root $Root
    try {
        $obj = New-Object PSObject
        foreach ($k in $Map.Keys) { $obj | Add-Member -NotePropertyName $k -NotePropertyValue (@($Map[$k])) }
        $obj | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
    } catch {
        Write-Log "Could not save known games: $($_.Exception.Message)" 'WARN'
    }
}

function Get-HistoryPath { param([Parameter(Mandatory)][string]$Root) return (Join-Path $Root 'history.json') }

function Add-HistoryEntries {
    <#
        Appends applied-icon records to history.json so the user can
        review what was changed and when. Keeps the most recent 500.
        $Entries is an array of @{ name; game; url; date }.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][array]$Entries
    )
    if (@($Entries).Count -eq 0) { return }
    $path = Get-HistoryPath -Root $Root
    $existing = @()
    if (Test-Path $path) {
        try { $existing = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) } catch { $existing = @() }
    }
    $all = @($Entries) + @($existing)          # newest first
    if ($all.Count -gt 500) { $all = $all[0..499] }
    try { $all | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8 }
    catch { Write-Log "Could not write history: $($_.Exception.Message)" 'WARN' }
}

function Get-History {
    param([Parameter(Mandatory)][string]$Root, [int]$Top = 200)
    $path = Get-HistoryPath -Root $Root
    if (-not (Test-Path $path)) { return @() }
    try {
        $h = @(Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
        if ($h.Count -gt $Top) { $h = $h[0..($Top-1)] }
        return $h
    } catch { return @() }
}
