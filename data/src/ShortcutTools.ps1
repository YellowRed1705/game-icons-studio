# ============================================================
#  ShortcutTools.ps1 - .lnk scanning, parsing, icon updating
#  Uses native WScript.Shell COM (no WinForms / no WPF)
# ============================================================

$script:WshShell = $null

function Get-WshShell {
    if ($null -eq $script:WshShell) {
        $script:WshShell = New-Object -ComObject WScript.Shell
    }
    return $script:WshShell
}

function Get-Shortcuts {
    <#
        Recursively scans a folder for .lnk files and extracts:
        name, target executable, current icon, working directory, arguments.
    #>
    param([Parameter(Mandatory)][string]$Folder)

    $results = New-Object System.Collections.Generic.List[object]
    $files = @()
    try {
        $files = Get-ChildItem -Path $Folder -Filter '*.lnk' -Recurse -File -ErrorAction SilentlyContinue
    } catch {
        Write-Log "Failed to enumerate folder '$Folder': $($_.Exception.Message)" 'ERROR'
        return $results
    }

    $wsh = Get-WshShell

    foreach ($file in $files) {
        try {
            $lnk = $wsh.CreateShortcut($file.FullName)
            $results.Add([PSCustomObject]@{
                Path             = $file.FullName
                Name             = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                Target           = $lnk.TargetPath
                Arguments        = $lnk.Arguments
                WorkingDirectory = $lnk.WorkingDirectory
                IconLocation     = $lnk.IconLocation
                NormalizedName   = $null   # filled later
                Status           = 'Pending'
                Detail           = ''
            })
        } catch {
            Write-Log "Invalid or unreadable shortcut skipped: $($file.FullName) ($($_.Exception.Message))" 'WARN'
            $results.Add([PSCustomObject]@{
                Path             = $file.FullName
                Name             = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                Target           = ''
                Arguments        = ''
                WorkingDirectory = ''
                IconLocation     = ''
                NormalizedName   = $null
                Status           = 'Failed'
                Detail           = 'Unreadable shortcut'
            })
        }
    }
    return $results
}

function Set-ShortcutIcon {
    <#
        Changes ONLY the icon of a shortcut.
        Target, arguments, working directory and all other
        properties are preserved (the COM object keeps them as-is;
        we only touch IconLocation before saving).
    #>
    param(
        [Parameter(Mandatory)][string]$ShortcutPath,
        [Parameter(Mandatory)][string]$IcoPath
    )

    if (-not (Test-Path $ShortcutPath)) { throw "Shortcut not found: $ShortcutPath" }
    if (-not (Test-Path $IcoPath))      { throw "Icon file not found: $IcoPath" }

    $wsh = Get-WshShell
    $lnk = $wsh.CreateShortcut($ShortcutPath)

    # Preserve everything: only IconLocation is modified.
    $lnk.IconLocation = "$IcoPath,0"
    $lnk.Save()
}

function Get-CurrentIconFile {
    <#
        Extracts the file part of an IconLocation string ("C:\path\x.ico,0").
        Returns $null when the icon lives inside an EXE/DLL or path is empty.
    #>
    param([string]$IconLocation)

    if ([string]::IsNullOrWhiteSpace($IconLocation)) { return $null }

    $pathPart = ($IconLocation -split ',')[0].Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($pathPart)) { return $null }

    $ext = [System.IO.Path]::GetExtension($pathPart).ToLowerInvariant()
    if ($ext -ne '.ico') { return $null }
    if (-not (Test-Path $pathPart)) { return $null }

    return $pathPart
}

function Get-NormalizedGameName {
    <#
        Cleans a shortcut name into a searchable game title.
        Removes edition suffixes, trademark symbols, bracketed tags.
    #>
    param([Parameter(Mandatory)][string]$Name)

    $n = $Name

    # Remove trademark / registered symbols
    $n = $n -replace '[\u2122\u00AE\u00A9]', ''

    # Remove bracketed/parenthesized tags: (2016), [GOG], etc.
    $n = $n -replace '\s*[\(\[\{][^\)\]\}]*[\)\]\}]', ''

    # Remove edition keywords (case-insensitive, word-boundary safe)
    $editionPatterns = @(
        'Game of the Year Edition',
        'Game of the Year',
        'GOTY Edition',
        'GOTY',
        "Director'?s Cut",
        'Deluxe Edition',
        'Digital Deluxe Edition',
        'Gold Edition',
        'Complete Edition',
        'Definitive Edition',
        'Ultimate Edition',
        'Enhanced Edition',
        'Anniversary Edition',
        'HD Remaster(ed)?',
        'Remastered',
        'Remaster'
    )
    foreach ($pattern in $editionPatterns) {
        $n = [regex]::Replace($n, "(?i)[\s:\-]*\b$pattern\b", '')
    }

    # Collapse separators and whitespace
    $n = $n -replace '[_]+', ' '
    $n = $n -replace '\s{2,}', ' '
    $n = $n.Trim(' ', '-', ':', '.')

    if ([string]::IsNullOrWhiteSpace($n)) { $n = $Name.Trim() }
    return $n
}

function Get-SafeFileName {
    param([Parameter(Mandatory)][string]$Name)
    $invalid = [System.IO.Path]::GetInvalidFileNameChars() -join ''
    $pattern = "[{0}]" -f [regex]::Escape($invalid)
    return ($Name -replace $pattern, '_').Trim()
}

# ---------------- v5 additions: shortcut metadata ----------------

function Get-ShortcutSteamAppId {
    <#
        Extracts a Steam AppID from a shortcut's target/arguments.
        Recognizes steam://rungameid/NNN and -applaunch NNN.
        Huge rungameid values are non-Steam shortcuts, so only
        plausible AppIDs (< 3,000,000) are accepted.
    #>
    param(
        [AllowEmptyString()][string]$Target,
        [AllowEmptyString()][string]$Arguments
    )

    $combined = "$Target $Arguments"
    if ($combined -match 'steam://rungameid/(\d+)') {
        $value = [int64]$matches[1]
        if ($value -gt 0 -and $value -lt 3000000) { return $value }
        return 0
    }
    if ($combined -match '-applaunch\s+(\d+)') {
        $value = [int64]$matches[1]
        if ($value -gt 0 -and $value -lt 3000000) { return $value }
    }
    return 0
}

function Get-GameYearFromName {
    <#
        Extracts a release year from a raw shortcut name, but ONLY
        when parenthesized - "(2018)" - so sequel numbers and titles
        like "Cyberpunk 2077" are never misread as years.
    #>
    param([AllowEmptyString()][string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return 0 }
    if ($Name -match '\(((19|20)\d{2})\)') {
        return [int]$matches[1]
    }
    return 0
}

# ---------------- v5.4: native multi-file picker ----------------

function Select-ShortcutFiles {
    <#
        Opens the native Windows multi-file picker and forces it to
        the FOREGROUND (topmost owner) so it never hides behind the
        browser or console. Returns an array of full .lnk paths, or
        an empty array if cancelled.

        Runs the dialog on a dedicated STA thread, because PowerShell 7
        (pwsh) is MTA by default and WinForms dialogs need STA - that
        mismatch is why the picker could silently fail to appear.
    #>
    param([string]$InitialFolder = '')

    $scriptBlock = {
        param($InitialFolder)
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        } catch { return @() }

        # A hidden topmost form to own the dialog and pull it to front.
        $owner = New-Object System.Windows.Forms.Form
        $owner.TopMost = $true
        $owner.ShowInTaskbar = $false
        $owner.Width = 0; $owner.Height = 0
        $owner.StartPosition = 'CenterScreen'
        $owner.Opacity = 0
        $owner.Show()
        $owner.Activate()

        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Select the shortcuts whose icons you want to change (Ctrl+click for multiple)'
        $dialog.Filter = 'Shortcuts (*.lnk)|*.lnk|All files (*.*)|*.*'
        $dialog.Multiselect = $true
        $dialog.CheckFileExists = $true
        if (-not [string]::IsNullOrWhiteSpace($InitialFolder) -and (Test-Path $InitialFolder)) {
            $dialog.InitialDirectory = $InitialFolder
        }

        $picked = @()
        $result = $dialog.ShowDialog($owner)
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) { $picked = @($dialog.FileNames) }
        $owner.Close(); $owner.Dispose()
        return ,$picked
    }

    # If we are already STA, just run it; otherwise spin a STA thread.
    try {
        if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA) {
            return @((& $scriptBlock $InitialFolder))
        }
    } catch { }

    try {
        $ps = [PowerShell]::Create()
        $ps.Runspace = [RunspaceFactory]::CreateRunspace()
        $ps.Runspace.ApartmentState = 'STA'
        $ps.Runspace.ThreadOptions = 'ReuseThread'
        $ps.Runspace.Open()
        [void]$ps.AddScript($scriptBlock).AddArgument($InitialFolder)
        $out = $ps.Invoke()
        $ps.Runspace.Close(); $ps.Dispose()
        return @($out)
    } catch {
        Write-Log "File picker failed: $($_.Exception.Message)" 'WARN'
        return @()
    }
}

function Get-ShortcutsFromPaths {
    <#
        Builds shortcut objects from an explicit list of .lnk paths
        (used by the file-picker "Change Icons" mode). Same shape as
        Get-Shortcuts output.
    #>
    param([Parameter(Mandatory)][string[]]$Paths)

    $results = New-Object System.Collections.Generic.List[object]
    $wsh = Get-WshShell

    foreach ($p in $Paths) {
        if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path $p)) { continue }
        try {
            $lnk = $wsh.CreateShortcut($p)
            $results.Add([PSCustomObject]@{
                Path             = $p
                Name             = [System.IO.Path]::GetFileNameWithoutExtension($p)
                Target           = $lnk.TargetPath
                Arguments        = $lnk.Arguments
                WorkingDirectory = $lnk.WorkingDirectory
                IconLocation     = $lnk.IconLocation
                NormalizedName   = $null
                Status           = 'Pending'
                Detail           = ''
            })
        } catch {
            Write-Log "Invalid or unreadable shortcut skipped: $p ($($_.Exception.Message))" 'WARN'
        }
    }
    return $results
}

function Get-InternetShortcuts {
    <#
        Scans a folder for Internet Shortcut files (.url) which some
        game launchers create instead of standard .lnk files. Returns
        a list with the parsed URL and the icon the .url references.
        Read-only: nothing is modified here.
    #>
    param([Parameter(Mandatory)][string]$Folder)

    $found = New-Object System.Collections.Generic.List[object]
    $files = @()
    try {
        $files = Get-ChildItem -Path $Folder -Filter '*.url' -Recurse -File -ErrorAction SilentlyContinue
    } catch {
        return $found
    }

    foreach ($file in $files) {
        try {
            $url = ''
            $iconFile = ''
            $iconIndex = 0
            foreach ($line in (Get-Content -LiteralPath $file.FullName -ErrorAction Stop)) {
                if ($line -match '^\s*URL\s*=\s*(.+)$')        { $url = $Matches[1].Trim() }
                elseif ($line -match '^\s*IconFile\s*=\s*(.+)$') { $iconFile = $Matches[1].Trim() }
                elseif ($line -match '^\s*IconIndex\s*=\s*(\d+)') { $iconIndex = [int]$Matches[1] }
            }
            if (-not [string]::IsNullOrWhiteSpace($url)) {
                $found.Add([PSCustomObject]@{
                    Path      = $file.FullName
                    Name      = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    Url       = $url
                    IconFile  = $iconFile
                    IconIndex = $iconIndex
                })
            }
        } catch {
            Write-Log "Could not read .url shortcut: $($file.FullName)" 'WARN'
        }
    }
    return $found
}

function Convert-InternetShortcut {
    <#
        Converts a single Internet Shortcut (.url) into a standard
        .lnk file in the SAME folder, preserving the launch URL by
        starting it through explorer.exe (which honours protocol
        handlers like com.epicgames.launcher://). The .lnk gets the
        same display name.

        SAFE BY DESIGN:
          - Creates the .lnk first and verifies it exists.
          - Only then (if -RemoveOriginal) deletes the .url.
          - On any failure, the original .url is left untouched.

        Returns the new .lnk path, or '' on failure.
    #>
    param(
        [Parameter(Mandatory)]$Shortcut,
        [bool]$RemoveOriginal = $true
    )

    try {
        $dir = Split-Path -Parent $Shortcut.Path
        $lnkPath = Join-Path $dir ($Shortcut.Name + '.lnk')

        # Avoid clobbering an existing .lnk with the same name.
        if (Test-Path $lnkPath) {
            $lnkPath = Join-Path $dir ($Shortcut.Name + ' (converted).lnk')
        }

        $wsh = Get-WshShell
        $lnk = $wsh.CreateShortcut($lnkPath)
        # explorer.exe launches the protocol URL exactly like a double
        # click on the .url would, so the game still starts normally.
        $lnk.TargetPath = "$env:WINDIR\explorer.exe"
        $lnk.Arguments  = '"' + $Shortcut.Url + '"'
        $lnk.WorkingDirectory = $env:WINDIR
        if (-not [string]::IsNullOrWhiteSpace($Shortcut.IconFile) -and (Test-Path $Shortcut.IconFile)) {
            $lnk.IconLocation = "$($Shortcut.IconFile),$($Shortcut.IconIndex)"
        }
        $lnk.Save()

        if (-not (Test-Path $lnkPath)) {
            Write-Log "Conversion failed (no .lnk produced) for: $($Shortcut.Path)" 'WARN'
            return ''
        }

        if ($RemoveOriginal) {
            try { Remove-Item -LiteralPath $Shortcut.Path -Force -ErrorAction Stop }
            catch { Write-Log "Converted but could not remove original .url: $($Shortcut.Path)" 'WARN' }
        }
        return $lnkPath
    } catch {
        Write-Log "Failed to convert .url shortcut '$($Shortcut.Path)': $($_.Exception.Message)" 'WARN'
        return ''
    }
}

function Get-FolderHealth {
    <#
        Quick pre-scan health report for a folder: how many .lnk, how
        many look broken (missing target), and how many .url launcher
        shortcuts exist. Read-only. Returns a hashtable.
    #>
    param([Parameter(Mandatory)][string]$Folder)

    $lnk = 0; $broken = 0; $url = 0
    try {
        $lnkFiles = @(Get-ChildItem -Path $Folder -Filter '*.lnk' -Recurse -File -ErrorAction SilentlyContinue)
        $lnk = $lnkFiles.Count
        $wsh = Get-WshShell
        foreach ($f in $lnkFiles) {
            try {
                $s = $wsh.CreateShortcut($f.FullName)
                $t = [string]$s.TargetPath
                # Broken if it has a filesystem target that no longer exists.
                if (-not [string]::IsNullOrWhiteSpace($t) -and ($t -match '^[A-Za-z]:\\') -and -not (Test-Path $t)) { $broken++ }
            } catch { $broken++ }
        }
    } catch { }
    try { $url = @(Get-ChildItem -Path $Folder -Filter '*.url' -Recurse -File -ErrorAction SilentlyContinue).Count } catch { }

    return @{ lnk = $lnk; broken = $broken; url = $url }
}
