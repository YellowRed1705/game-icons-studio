# ============================================================
#  ShortcutTools.ps1 - .lnk scanning, parsing, icon updating
#  Uses native WScript.Shell COM (no WinForms / no WPF)
# ============================================================

$script:WshShell = $null

function Get-EmulatorLauncherFamily {
    <#
        Returns the emulator family for a plain launcher shortcut target.
        Shortcuts with arguments are ROM/game launch commands, not app launchers.
    #>
    param([string]$TargetPath = '',[string]$Arguments = '')
    if ([string]::IsNullOrWhiteSpace($TargetPath) -or -not [string]::IsNullOrWhiteSpace($Arguments)) { return '' }
    $leaf = [System.IO.Path]::GetFileNameWithoutExtension($TargetPath)
    switch -Regex ($leaf) {
        '^(?i:cemu)(?:[-_].*)?$' { return 'cemu' }
        '^(?i:ryujinx|ryubing)$' { return 'ryujinx' }
        '^(?i:eden)$' { return 'eden' }
        '^(?i:yuzu)$' { return 'yuzu' }
        '^(?i:dolphin)(?:-qt)?$' { return 'dolphin' }
        '^(?i:mgba)$' { return 'mgba' }
        '^(?i:melonds)$' { return 'melonds' }
        '^(?i:azahar)$' { return 'azahar' }
        '^(?i:citra)(?:-qt)?$' { return 'citra' }
        '^(?i:pcsx2)(?:-qt)?$' { return 'pcsx2' }
    }
    return ''
}

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

function Test-ValidIcoFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            if ($stream.Length -lt 22) { return $false }
            $header = New-Object byte[] 6
            if ($stream.Read($header,0,6) -ne 6) { return $false }
            $count = [BitConverter]::ToUInt16($header,4)
            return ($header[0] -eq 0 -and $header[1] -eq 0 -and $header[2] -eq 1 -and $header[3] -eq 0 -and $count -gt 0)
        } finally { $stream.Dispose() }
    } catch { return $false }
}

function Set-ShortcutIcon {
    <#
        Changes ONLY IconLocation. Target, arguments and working directory
        remain untouched. A valid persistent ICO is required before saving.
    #>
    param(
        [Parameter(Mandatory)][string]$ShortcutPath,
        [Parameter(Mandatory)][string]$IcoPath
    )

    if (-not (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) { throw "Shortcut not found: $ShortcutPath" }
    if (-not (Test-ValidIcoFile -Path $IcoPath)) { throw "Icon file is missing or invalid: $IcoPath" }

    $fullIco = [System.IO.Path]::GetFullPath($IcoPath)
    $wsh = Get-WshShell
    $lnk = $wsh.CreateShortcut($ShortcutPath)
    $originalTarget = [string]$lnk.TargetPath
    $originalArguments = [string]$lnk.Arguments
    $originalWorkingDirectory = [string]$lnk.WorkingDirectory
    $lnk.IconLocation = "$fullIco,0"
    $lnk.Save()

    $verify = $wsh.CreateShortcut($ShortcutPath)
    if ([string]$verify.TargetPath -ne $originalTarget -or
        [string]$verify.Arguments -ne $originalArguments -or
        [string]$verify.WorkingDirectory -ne $originalWorkingDirectory) {
        throw "Shortcut launch settings changed unexpectedly while updating its icon: $ShortcutPath"
    }
    if (([string]$verify.IconLocation -split ',')[0].Trim('"') -ine $fullIco) {
        throw "Windows did not persist the new icon location: $ShortcutPath"
    }
}

function Set-FileCustomIconShortcut {
    <#
        Creates a standard Windows .lnk beside an executable, script, ROM or
        other file whose Explorer icon cannot be individually customized.
        ROMs use their registered Windows emulator association by default.
        A detected emulator profile can override the launch target/arguments.
    #>
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$ShortcutPath,
        [Parameter(Mandatory)][string]$IcoPath,
        [string]$LaunchTargetPath = '',
        [string]$LaunchArguments = '',
        [string]$LaunchWorkingDirectory = ''
    )
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "Source file not found: $FilePath" }
    if (-not (Test-ValidIcoFile -Path $IcoPath)) { throw "Icon file is missing or invalid: $IcoPath" }

    $fullFile = [System.IO.Path]::GetFullPath($FilePath)
    $fullIco = [System.IO.Path]::GetFullPath($IcoPath)
    $extension = [System.IO.Path]::GetExtension($fullFile).ToLowerInvariant()
    $directory = [System.IO.Path]::GetDirectoryName($fullFile)
    $shell = Get-WshShell
    $link = $shell.CreateShortcut($ShortcutPath)

    if (-not [string]::IsNullOrWhiteSpace($LaunchTargetPath)) {
        if (-not (Test-Path -LiteralPath $LaunchTargetPath -PathType Leaf)) { throw "Configured emulator or launcher was not found: $LaunchTargetPath" }
        $link.TargetPath = [System.IO.Path]::GetFullPath($LaunchTargetPath)
        $link.Arguments = [string]$LaunchArguments
        $link.WorkingDirectory = if (-not [string]::IsNullOrWhiteSpace($LaunchWorkingDirectory)) { $LaunchWorkingDirectory } else { [System.IO.Path]::GetDirectoryName($LaunchTargetPath) }
    } elseif ($extension -in @('.ps1','.psm1','.psd1')) {
        $psExe = $null
        try { $psExe = (Get-Command pwsh.exe -ErrorAction Stop).Source } catch { }
        if ([string]::IsNullOrWhiteSpace($psExe)) {
            try { $psExe = (Get-Command powershell.exe -ErrorAction Stop).Source } catch { }
        }
        if ([string]::IsNullOrWhiteSpace($psExe)) { throw 'PowerShell executable was not found.' }
        $link.TargetPath = $psExe
        $link.Arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $fullFile + '"'
        $link.WorkingDirectory = $directory
    } elseif ($extension -in @('.bat','.cmd')) {
        $cmdExe = [string]$env:ComSpec
        if ([string]::IsNullOrWhiteSpace($cmdExe)) { $cmdExe = Join-Path $env:SystemRoot 'System32\cmd.exe' }
        $link.TargetPath = $cmdExe
        $link.Arguments = '/d /c ""' + $fullFile + '""'
        $link.WorkingDirectory = $directory
    } else {
        # ShellExecute opens ROMs and other registered document/file types
        # with their Windows default application (e.g. an installed emulator).
        $link.TargetPath = $fullFile
        $link.Arguments = ''
        $link.WorkingDirectory = $directory
    }

    $link.IconLocation = "$fullIco,0"
    $link.Save()

    if (-not (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) { throw "Windows did not create the shortcut: $ShortcutPath" }
    $verify = $shell.CreateShortcut($ShortcutPath)
    if (([string]$verify.IconLocation -split ',')[0].Trim('"') -ine $fullIco) {
        throw "Windows did not persist the custom icon on: $ShortcutPath"
    }
    if (-not [string]::IsNullOrWhiteSpace($LaunchTargetPath)) {
        if ([string]$verify.TargetPath -ine [System.IO.Path]::GetFullPath($LaunchTargetPath) -or
            [string]$verify.Arguments -ne [string]$LaunchArguments) {
            throw "The emulator launch command was not saved correctly: $ShortcutPath"
        }
    } elseif ($extension -notin @('.ps1','.psm1','.psd1','.bat','.cmd')) {
        if ([string]$verify.TargetPath -ine $fullFile) { throw "The file association target was not saved correctly: $ShortcutPath" }
    }
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
        $dialog.Title = 'Select shortcuts or files whose icons you want to customize (Ctrl+click for multiple)'
        $dialog.Filter = 'All supported files (*.*)|*.*'
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
        Builds scan targets from selected shortcut/file paths. Existing .lnk
        files are edited in place. Other launchable files get a clean, standard
        sibling .lnk; if that name is occupied by an unrelated shortcut, a
        clearly labelled companion name is used.
    #>
    param([Parameter(Mandatory)][string[]]$Paths)

    $results = New-Object System.Collections.Generic.List[object]
    $wsh = Get-WshShell

    foreach ($p in $Paths) {
        if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
        try {
            $fullPath = [System.IO.Path]::GetFullPath($p)
            $extension = [System.IO.Path]::GetExtension($fullPath)
            if ($extension -ieq '.lnk') {
                $lnk = $wsh.CreateShortcut($fullPath)
                $results.Add([PSCustomObject]@{
                    Path = $fullPath
                    Name = [System.IO.Path]::GetFileNameWithoutExtension($fullPath)
                    Target = [string]$lnk.TargetPath
                    Arguments = [string]$lnk.Arguments
                    WorkingDirectory = [string]$lnk.WorkingDirectory
                    IconLocation = [string]$lnk.IconLocation
                    NormalizedName = $null
                    Status = 'Pending'
                    Detail = ''
                    IsGeneratedFileShortcut = $false
                })
                continue
            }

            $dir = [System.IO.Path]::GetDirectoryName($fullPath)
            $stem = [System.IO.Path]::GetFileNameWithoutExtension($fullPath)
            $shortcutPath = Join-Path $dir ($stem + '.lnk')
            $suffix = 2
            $reuseExisting = $false
            while (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
                $existing = $wsh.CreateShortcut($shortcutPath)
                $isSame = ([string]$existing.TargetPath -ieq $fullPath) -or
                    ([string]$existing.Arguments).IndexOf($fullPath,[System.StringComparison]::OrdinalIgnoreCase) -ge 0
                if ($isSame) { $reuseExisting = $true; break }
                if ($suffix -eq 2) { $shortcutPath = Join-Path $dir ($stem + ' (Custom Icon).lnk') }
                else { $shortcutPath = Join-Path $dir ($stem + ' (Custom Icon ' + $suffix + ').lnk') }
                $suffix++
            }

            $results.Add([PSCustomObject]@{
                Path = $shortcutPath
                Name = $stem
                Target = $fullPath
                Arguments = ''
                WorkingDirectory = $dir
                IconLocation = ''
                NormalizedName = $null
                Status = 'Pending'
                Detail = if ($reuseExisting) { 'An existing matching shortcut will be updated.' } else { 'A standard Windows .lnk will be created beside the original file; the source remains untouched.' }
                IsGeneratedFileShortcut = (-not $reuseExisting)
                SourcePath = $fullPath
                LaunchTargetPath = ''
                LaunchArguments = ''
                LaunchWorkingDirectory = $dir
            })
        } catch {
            Write-Log "File target skipped: $p ($($_.Exception.Message))" 'WARN'
        }
    }
    return $results
}

function Test-SupportedLauncherUri {
    param([Parameter(Mandatory)][string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url) -or $Url -match '[\r\n\x00"]') { return $false }
    $parsed = $null
    if (-not [Uri]::TryCreate($Url,[UriKind]::Absolute,[ref]$parsed)) { return $false }
    $scheme = ([string]$parsed.Scheme).ToLowerInvariant()
    if ($scheme -in @('http','https','steam','uplay','battlenet','origin2','link2ea','eaapp',
        'com.epicgames.launcher','ms-xbox','ms-xboxgamepass','ms-xbox-gamepass','xbox',
        'roblox-player','minecraft','discord','spotify','goggalaxy')) { return $true }
    # Also allow other protocols only when Windows has a registered URL handler.
    try {
        $protocolKey = "Registry::HKEY_CLASSES_ROOT\$scheme"
        if (-not (Test-Path -LiteralPath $protocolKey)) { return $false }
        $item = Get-Item -LiteralPath $protocolKey -ErrorAction Stop
        return ($item.GetValueNames() -contains 'URL Protocol')
    } catch { return $false }
}

function Get-InternetShortcuts {
    <#
        Recursively reads Windows Internet Shortcuts using literal folder paths.
        Supports Steam, Epic, Ubisoft, Battle.net, EA, Xbox and other registered
        application URI protocols. The discovery operation is read-only.
    #>
    param([Parameter(Mandatory)][string]$Folder)

    $found = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($Folder) -or -not (Test-Path -LiteralPath $Folder -PathType Container)) { return $found }
    $files = @()
    try {
        $files = @(Get-ChildItem -LiteralPath $Folder -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -ieq '.url' })
    } catch { return $found }

    foreach ($file in $files) {
        try {
            $url = ''
            $iconFile = ''
            $iconIndex = 0
            foreach ($line in [System.IO.File]::ReadAllLines($file.FullName)) {
                if ($line -match '^\s*URL\s*=\s*(.*?)\s*$') { $url = $Matches[1].Trim() }
                elseif ($line -match '^\s*IconFile\s*=\s*(.*?)\s*$') { $iconFile = [Environment]::ExpandEnvironmentVariables($Matches[1].Trim().Trim('"')) }
                elseif ($line -match '^\s*IconIndex\s*=\s*(-?\d+)') { $iconIndex = [int]$Matches[1] }
            }
            if (Test-SupportedLauncherUri -Url $url) {
                $found.Add([PSCustomObject]@{
                    Path = $file.FullName
                    Name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    Url = $url
                    IconFile = $iconFile
                    IconIndex = $iconIndex
                    Scheme = ([Uri]$url).Scheme.ToLowerInvariant()
                })
            } elseif (-not [string]::IsNullOrWhiteSpace($url)) {
                Write-Log "Unsupported or unregistered launcher protocol in '$($file.FullName)': $url" 'WARN'
            }
        } catch {
            Write-Log "Could not read .url shortcut: $($file.FullName) ($($_.Exception.Message))" 'WARN'
        }
    }
    return $found
}

function Convert-InternetShortcut {
    <#
        Converts a .url launcher into a standard, verified .lnk that delegates
        its URI to Windows Explorer and the registered protocol handler.
        The source URL is removed only when requested and only after verifying
        the destination shortcut can be read back with the original URI.
    #>
    param(
        [Parameter(Mandatory)]$Shortcut,
        [bool]$RemoveOriginal = $true
    )

    try {
        if (-not (Test-SupportedLauncherUri -Url ([string]$Shortcut.Url))) {
            throw "Unsupported or unregistered launcher URI: $([string]$Shortcut.Url)"
        }
        $dir = Split-Path -Parent $Shortcut.Path
        $stem = [string]$Shortcut.Name
        $lnkPath = Join-Path $dir ($stem + '.lnk')
        $suffix = 2
        $wsh = Get-WshShell
        while (Test-Path -LiteralPath $lnkPath -PathType Leaf) {
            $existing = $wsh.CreateShortcut($lnkPath)
            $sameUri = ([string]$existing.Arguments).IndexOf([string]$Shortcut.Url,[System.StringComparison]::OrdinalIgnoreCase) -ge 0
            if ([string]$existing.TargetPath -ieq (Join-Path $env:WINDIR 'explorer.exe') -and $sameUri) {
                if ($RemoveOriginal -and (Test-Path -LiteralPath $Shortcut.Path -PathType Leaf)) {
                    Remove-Item -LiteralPath $Shortcut.Path -Force -ErrorAction Stop
                }
                return $lnkPath
            }
            if ($suffix -eq 2) { $lnkPath = Join-Path $dir ($stem + ' (converted).lnk') }
            else { $lnkPath = Join-Path $dir ($stem + ' (converted ' + $suffix + ').lnk') }
            $suffix++
        }

        $lnk = $wsh.CreateShortcut($lnkPath)
        $lnk.TargetPath = Join-Path $env:WINDIR 'explorer.exe'
        $lnk.Arguments = '"' + [string]$Shortcut.Url + '"'
        $lnk.WorkingDirectory = $env:WINDIR
        if (-not [string]::IsNullOrWhiteSpace([string]$Shortcut.IconFile) -and
            (Test-Path -LiteralPath ([string]$Shortcut.IconFile) -PathType Leaf)) {
            $lnk.IconLocation = '"' + [string]$Shortcut.IconFile + '",' + [int]$Shortcut.IconIndex
        }
        $lnk.Save()

        if (-not (Test-Path -LiteralPath $lnkPath -PathType Leaf)) { throw 'Windows did not create the converted .lnk.' }
        $verify = $wsh.CreateShortcut($lnkPath)
        if ([string]$verify.TargetPath -ine (Join-Path $env:WINDIR 'explorer.exe') -or
            ([string]$verify.Arguments).IndexOf([string]$Shortcut.Url,[System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw 'The converted shortcut did not preserve the original launcher URI.'
        }
        if ($RemoveOriginal) { Remove-Item -LiteralPath $Shortcut.Path -Force -ErrorAction Stop }
        return $lnkPath
    } catch {
        Write-Log "Failed to convert .url shortcut '$($Shortcut.Path)': $($_.Exception.Message)" 'WARN'
        return ''
    }
}

function Get-FolderHealth {
    <#
        Read-only recursive health summary. Uses LiteralPath + Force so
        folders containing wildcard characters and hidden entries are handled.
    #>
    param([Parameter(Mandatory)][string]$Folder)

    $lnk = 0; $broken = 0; $url = 0
    try {
        $allFiles = @(Get-ChildItem -LiteralPath $Folder -Recurse -File -Force -ErrorAction SilentlyContinue)
        $lnkFiles = @($allFiles | Where-Object { $_.Extension -ieq '.lnk' })
        $urlFiles = @($allFiles | Where-Object { $_.Extension -ieq '.url' })
        $lnk = $lnkFiles.Count
        $url = $urlFiles.Count
        $wsh = Get-WshShell
        foreach ($file in $lnkFiles) {
            try {
                $shortcut = $wsh.CreateShortcut($file.FullName)
                $target = [string]$shortcut.TargetPath
                if (-not [string]::IsNullOrWhiteSpace($target) -and
                    ($target -match '^[A-Za-z]:\\|^\\\\') -and
                    -not (Test-Path -LiteralPath $target)) { $broken++ }
            } catch { $broken++ }
        }
    } catch {
        Write-Log "Folder health scan failed for '$Folder': $($_.Exception.Message)" 'WARN'
    }
    return @{ lnk = $lnk; broken = $broken; url = $url }
}
