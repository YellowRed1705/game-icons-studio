# ============================================================
#  WebServer.ps1 (v6) - Local browser-driven mode
#  A tiny HttpListener server on http://localhost:PORT that
#  serves a single-page web app and a small JSON API. The whole
#  workflow (folder pick, scan, match, cover choice, apply, live
#  report) happens in the browser; CMD just shows the server URL.
#
#  No external dependencies: HttpListener ships with .NET.
# ============================================================

$script:SgdbHttpPort = 8765

function Get-FreePort {
    <#
        Finds a free TCP port starting at $Start. Returns the port
        number, or the start value if probing fails.
    #>
    param([int]$Start = 8765)
    for ($p = $Start; $p -lt ($Start + 40); $p++) {
        try {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $p)
            $listener.Start()
            $listener.Stop()
            return $p
        } catch {
            continue
        }
    }
    return $Start
}

function Send-HttpResponse {
    <#
        Writes a response to the HttpListener context. $Body is a
        string; $ContentType defaults to JSON. Always closes the
        output stream.
    #>
    param(
        [Parameter(Mandatory)]$Context,
        [string]$Body = '',
        [string]$ContentType = 'application/json; charset=utf-8',
        [int]$StatusCode = 200
    )
    try {
        $response = $Context.Response
        $response.StatusCode = $StatusCode
        $response.ContentType = $ContentType
        $response.Headers['Cache-Control'] = 'no-cache, no-store'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
        $response.OutputStream.Close()
    } catch {
        Write-Log "Failed to send HTTP response: $($_.Exception.Message)" 'WARN' $true
    }
}

function Send-HttpFile {
    <#
        Streams a binary file (image) to the browser. Used to serve
        branding assets from the Assets folder.
    #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$FilePath,
        [string]$ContentType = 'application/octet-stream',
        [int]$StatusCode = 200
    )
    try {
        $response = $Context.Response
        $response.StatusCode = $StatusCode
        $response.ContentType = $ContentType
        $response.Headers['Cache-Control'] = 'public, max-age=3600'
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
        $response.OutputStream.Close()
    } catch {
        Write-Log "Failed to send file: $($_.Exception.Message)" 'WARN' $true
    }
}

function Read-RequestBody {
    <#
        Reads the full request body as a string (for POST JSON).
    #>
    param([Parameter(Mandatory)]$Context)
    try {
        $reader = New-Object System.IO.StreamReader($Context.Request.InputStream, $Context.Request.ContentEncoding)
        $text = $reader.ReadToEnd()
        $reader.Dispose()
        return $text
    } catch {
        return ''
    }
}

function ConvertTo-JsonSafe {
    <#
        ConvertTo-Json with a sane default depth and compression,
        guarding against the single-element-unwrapping quirk by
        always wrapping arrays at the call site.
    #>
    param([Parameter(Mandatory)][AllowNull()]$Data, [int]$Depth = 8)
    if ($null -eq $Data) { return 'null' }
    return ($Data | ConvertTo-Json -Depth $Depth -Compress)
}

function Start-IconWebApp {
    <#
        Boots the local web app: starts HttpListener on a free port,
        opens the browser, then serves requests on this thread until
        the user finishes (the page calls /api/quit) or presses Q in
        the console. All heavy work (SteamGridDB calls, downloads,
        icon build, apply) is dispatched from the route handlers via
        the same functions the CMD modes use.

        $Ctx is a run context WITHOUT a fixed folder; the browser
        chooses everything.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Ctx
    )

    $port = Get-FreePort -Start $script:SgdbHttpPort
    $prefix = "http://localhost:$port/"

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)
    try {
        $listener.Start()
    } catch {
        Write-ErrorDetails -ErrorRecord $_ -Context 'Web server start'
        Write-Host ''
        Write-Host '  Could not start the local web server. Falling back to the' -ForegroundColor Yellow
        Write-Host '  classic flow is recommended (menu option for CMD mode).' -ForegroundColor Yellow
        return $false
    }

    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
    Write-Host "   Browser mode is live at:  $prefix" -ForegroundColor Cyan
    Write-Host '   Your browser should open automatically.' -ForegroundColor Gray
    Write-Host '   Do everything in the browser. Press Q here to stop.' -ForegroundColor Gray
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
    Write-Log "Web server started at $prefix" 'OK'

    try { Start-Process -FilePath $prefix } catch {
        Write-Host "  Open this in your browser: $prefix" -ForegroundColor Yellow
    }

    # Minimize this console so it stays out of the way and never steals
    # focus from the browser. The app is fully driven from the browser.
    try {
        Add-Type -Namespace W -Name Con -MemberDefinition '
            [DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
            [DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int n);
        ' -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 1200
        $hwnd = [W.Con]::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero) { [void][W.Con]::ShowWindow($hwnd, 6) }  # 6 = SW_MINIMIZE
    } catch { }

    # Shared state for the session (browser drives everything).
    # The browser drives scanning one game per request, so progress
    # is naturally live with no background threads.
    # Dialog is a synchronized store for the async folder/file picker
    # so opening a native window never blocks the HTTP server thread.
    $dialog = [hashtable]::Synchronized(@{
        status = 'idle'    # idle | running | done
        kind   = ''        # folder | files
        folder = ''
        files  = @()
        ps     = $null
        handle = $null
    })
    $session = [PSCustomObject]@{
        Ctx        = $Ctx
        Root       = $Root
        Shortcuts  = @()
        Names      = @()    # unique game names queued for scanning
        Pending    = @()    # resolved sections per game
        Running    = $true
        Dialog     = $dialog
        CoverCache = @{}    # gameId -> covers, to avoid repeat API calls
    }

    # Serve until quit. Use async GetContext so we can poll Q key.
    while ($session.Running) {
        $asyncResult = $listener.BeginGetContext($null, $null)
        while (-not $asyncResult.AsyncWaitHandle.WaitOne(200)) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq [ConsoleKey]::Q) {
                    $session.Running = $false
                    break
                }
            }
        }
        if (-not $session.Running) { break }

        $context = $listener.EndGetContext($asyncResult)
        try {
            Invoke-WebRoute -Context $context -Session $session
        } catch {
            Write-ErrorDetails -ErrorRecord $_ -Context 'Web route'
            try { Send-HttpResponse -Context $context -Body (ConvertTo-JsonSafe @{ ok = $false; error = $_.Exception.Message }) -StatusCode 500 } catch { }
        }
    }

    try { $listener.Stop(); $listener.Close() } catch { }
    Write-Log 'Web server stopped.' 'INFO'
    return $true
}

function Invoke-WebRoute {
    <#
        Routes one HTTP request. GET / serves the app HTML; the
        /api/* endpoints return JSON and perform the actual work.
    #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Session
    )

    $req = $Context.Request
    $path = $req.Url.AbsolutePath.ToLowerInvariant()
    $method = $req.HttpMethod.ToUpperInvariant()

    if ($path -eq '/' -and $method -eq 'GET') {
        Send-HttpResponse -Context $Context -Body (Get-WebAppHtml) -ContentType 'text/html; charset=utf-8'
        return
    }

    if ($path -like '/assets/*' -and $method -eq 'GET') {
        # Serve branding images (header.png, brand.png, app.png) from
        # the Assets folder. Path is locked to the Assets dir.
        $name = Split-Path -Leaf $path
        $assetPath = Join-Path (Join-Path $Session.Root 'Assets') $name
        if ((Test-Path $assetPath) -and ($name -match '^[\w.-]+\.(png|ico|jpg|jpeg|svg)$')) {
            $ct = switch -Regex ($name) {
                '\.png$'  { 'image/png' }
                '\.ico$'  { 'image/x-icon' }
                '\.svg$'  { 'image/svg+xml' }
                default   { 'image/jpeg' }
            }
            Send-HttpFile -Context $Context -FilePath $assetPath -ContentType $ct
        } else {
            Send-HttpResponse -Context $Context -Body '' -StatusCode 404
        }
        return
    }

    if ($path -eq '/api/quit' -and $method -eq 'POST') {
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true })
        $Session.Running = $false
        return
    }

    if ($path -eq '/api/finish' -and $method -eq 'POST') {
        # Open the processed folder in Explorer (Large Icons view) so the
        # user sees the new shelf immediately, then shut the app down.
        $folder = [string]$Session.Ctx.Folder
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true })
        try { Open-FolderLargeIcons -Folder $folder } catch { }
        $Session.Running = $false
        return
    }

    if ($path -eq '/api/key-status' -and $method -eq 'POST') {
        $hasKey = -not [string]::IsNullOrWhiteSpace($Session.Ctx.ApiKey)
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true; hasKey = $hasKey })
        return
    }

    if ($path -eq '/api/save-key' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $key = if ($body) { ([string]$body.key).Trim() } else { '' }
        if ([string]::IsNullOrWhiteSpace($key)) {
            Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $false; error = 'Empty key.' })
            return
        }
        $valid = $false
        try { $valid = Test-SgdbConnection -ApiKey $key }
        catch [System.UnauthorizedAccessException] { $valid = $false }
        catch { $valid = $false }
        if (-not $valid) {
            Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $false; error = 'That key did not work. Double-check and try again.' })
            return
        }
        $Session.Ctx.ApiKey = $key
        $Session.Ctx.Settings.ApiKey = $key
        Save-Settings -Root $Session.Root -Settings $Session.Ctx.Settings
        Write-Log 'API key saved from the browser.' 'OK'
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true })
        return
    }

    if ($path -eq '/api/browse-folder' -and $method -eq 'POST') {
        # Non-blocking: start the picker on its own thread and return.
        Start-AsyncDialog -Dialog $Session.Dialog -Kind 'folder' -InitialFolder ([string]$Session.Ctx.Settings.LastFolder)
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true; started = $true })
        return
    }

    if ($path -eq '/api/validate-folder' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $folder = if ($body) { [string]$body.folder } else { '' }
        $valid = (-not [string]::IsNullOrWhiteSpace($folder)) -and (Test-Path $folder)
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $valid; folder = $folder })
        return
    }

    if ($path -eq '/api/last-folder' -and $method -eq 'POST') {
        $lf = [string]$Session.Ctx.Settings.LastFolder
        $valid = (-not [string]::IsNullOrWhiteSpace($lf)) -and (Test-Path $lf)
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $valid; folder = $lf })
        return
    }

    if ($path -eq '/api/change-files' -and $method -eq 'POST') {
        # Non-blocking: start the multi-file picker on its own thread.
        Start-AsyncDialog -Dialog $Session.Dialog -Kind 'files' -InitialFolder ([string]$Session.Ctx.Settings.LastFolder)
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true; started = $true })
        return
    }

    if ($path -eq '/api/dialog-status' -and $method -eq 'POST') {
        $d = $Session.Dialog
        if ($d.status -eq 'done') {
            # Clean up the worker runspace
            try { if ($d.ps) { $d.ps.EndInvoke($d.handle); $d.ps.Runspace.Close(); $d.ps.Dispose(); $d.ps = $null } } catch { }
            if ($d.kind -eq 'folder') {
                $folder = [string]$d.folder
                $d.status = 'idle'
                Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ status = 'done'; kind = 'folder'; ok = (-not [string]::IsNullOrWhiteSpace($folder)); folder = $folder })
            } else {
                $files = @($d.files | ForEach-Object { [string]$_ })
                $d.status = 'idle'
                Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ status = 'done'; kind = 'files'; ok = ($files.Count -gt 0); files = $files })
            }
            return
        }
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ status = $d.status })
        return
    }

    if ($path -eq '/api/scan-files-begin' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $files = @()
        if ($body -and $body.files) { $files = @($body.files | ForEach-Object { [string]$_ }) }
        $result = Start-WebScanFiles -Session $Session -Files $files
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe $result)
        return
    }

    if ($path -eq '/api/check-url-shortcuts' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $folder = if ($body -and $body.folder) { [string]$body.folder } else { $Session.Ctx.Folder }
        $urls = @()
        if (-not [string]::IsNullOrWhiteSpace($folder) -and (Test-Path $folder)) {
            $urls = @(Get-InternetShortcuts -Folder $folder)
        }
        $lnks = @()
        if (-not [string]::IsNullOrWhiteSpace($folder) -and (Test-Path $folder)) {
            try { $lnks = @(Get-ChildItem -Path $folder -Filter '*.lnk' -Recurse -File -ErrorAction SilentlyContinue) } catch { }
        }
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true; urlCount = $urls.Count; lnkCount = $lnks.Count })
        return
    }

    if ($path -eq '/api/convert-shortcuts' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $folder = if ($body -and $body.folder) { [string]$body.folder } else { $Session.Ctx.Folder }
        $converted = 0; $failed = 0
        if (-not [string]::IsNullOrWhiteSpace($folder) -and (Test-Path $folder)) {
            foreach ($u in @(Get-InternetShortcuts -Folder $folder)) {
                $new = Convert-InternetShortcut -Shortcut $u -RemoveOriginal $true
                if (-not [string]::IsNullOrWhiteSpace($new)) { $converted++ } else { $failed++ }
            }
        }
        Write-Log "Converted $converted .url shortcuts ($failed failed)." 'INFO'
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true; converted = $converted; failed = $failed })
        return
    }

    if ($path -eq '/api/saved-status' -and $method -eq 'POST') {
        # How many remembered choices exist (covers + game pins).
        $choices = 0
        try { $choices = @($Session.Ctx.SavedChoices.Keys).Count } catch { }
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true; count = $choices })
        return
    }

    if ($path -eq '/api/reset-choices' -and $method -eq 'POST') {
        # Forget remembered picks for a clean start.
        try {
            $Session.Ctx.SavedChoices = @{}
            $Session.Ctx.Overrides = @{}
            Save-SavedChoices -Root $Session.Root -Choices $Session.Ctx.SavedChoices
            Save-Overrides -Root $Session.Root -Overrides $Session.Ctx.Overrides
            Write-Log 'User reset all remembered choices.' 'INFO'
        } catch { }
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true })
        return
    }

    if ($path -eq '/api/repair-cache' -and $method -eq 'POST') {
        $okc = Repair-IconCache
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = [bool]$okc })
        return
    }

    if ($path -eq '/api/folder-health' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $folder = if ($body -and $body.folder) { [string]$body.folder } else { $Session.Ctx.Folder }
        $h = @{ lnk = 0; broken = 0; url = 0 }
        if (-not [string]::IsNullOrWhiteSpace($folder) -and (Test-Path $folder)) {
            $h = Get-FolderHealth -Folder $folder
        }
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe (@{ ok = $true } + $h))
        return
    }

    if ($path -eq '/api/scan-begin' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $folder = if ($body -and $body.folder) { [string]$body.folder } else { $Session.Ctx.Folder }

        if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path $folder)) {
            Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $false; error = 'Folder not found.' })
            return
        }
        $Session.Ctx.Folder = $folder
        # Only write settings to disk when the remembered folder actually
        # changed, to avoid a redundant write on every scan.
        if ([string]$Session.Ctx.Settings.LastFolder -ne [string]$folder) {
            $Session.Ctx.Settings.LastFolder = $folder
            Save-Settings -Root $Session.Root -Settings $Session.Ctx.Settings
        }

        $onlyNew  = if ($body -and $body.onlyNew)  { [bool]$body.onlyNew }    else { $false }

        $result = Start-WebScan -Session $Session -OnlyNew $onlyNew

        # Remember the full set of games in this folder for new-game
        # detection next time. On a full scan we can reuse the list the
        # scan already built; only re-read when the scan was filtered.
        try {
            if (-not $onlyNew -and @($Session.Shortcuts).Count -gt 0) {
                $allNames = @($Session.Shortcuts | Where-Object { $_.Status -ne 'Failed' } | ForEach-Object { [string]$_.NormalizedName } | Sort-Object -Unique)
            } else {
                $allShort = @(Get-Shortcuts -Folder $folder)
                foreach ($s in $allShort) { if ($s.Status -ne 'Failed') { $s.NormalizedName = Get-NormalizedGameName -Name $s.Name } }
                $allNames = @($allShort | Where-Object { $_.Status -ne 'Failed' } | ForEach-Object { [string]$_.NormalizedName } | Sort-Object -Unique)
            }
            $known = Get-KnownGames -Root $Session.Root
            $key = ([string]$folder).ToLowerInvariant()
            # Only rewrite the file if this folder's game list actually
            # changed (avoids a disk write on every repeat scan).
            $prevList = @()
            if ($known.ContainsKey($key)) { $prevList = @($known[$key]) }
            $changed = ($prevList.Count -ne $allNames.Count)
            if (-not $changed) {
                for ($ix = 0; $ix -lt $allNames.Count; $ix++) {
                    if ([string]$prevList[$ix] -ne [string]$allNames[$ix]) { $changed = $true; break }
                }
            }
            if ($changed) {
                $known[$key] = $allNames
                Save-KnownGames -Root $Session.Root -Map $known
            }
        } catch { }

        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe $result)
        return
    }

    if ($path -eq '/api/new-games-count' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $folder = if ($body -and $body.folder) { [string]$body.folder } else { $Session.Ctx.Folder }
        $newCount = 0; $isKnownFolder = $false
        if (-not [string]::IsNullOrWhiteSpace($folder) -and (Test-Path $folder)) {
            try {
                $short = @(Get-Shortcuts -Folder $folder)
                foreach ($s in $short) { if ($s.Status -ne 'Failed') { $s.NormalizedName = Get-NormalizedGameName -Name $s.Name } }
                $names = @($short | Where-Object { $_.Status -ne 'Failed' } | ForEach-Object { [string]$_.NormalizedName } | Sort-Object -Unique)
                $known = Get-KnownGames -Root $Session.Root
                $key = ([string]$folder).ToLowerInvariant()
                if ($known.ContainsKey($key)) {
                    $isKnownFolder = $true
                    $prev = @($known[$key])
                    $newCount = @($names | Where-Object { $prev -notcontains $_ }).Count
                }
            } catch { }
        }
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true; newCount = $newCount; knownFolder = $isKnownFolder })
        return
    }

    if ($path -eq '/api/game-covers' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $gameId = if ($body -and $null -ne $body.gameId) { [int]$body.gameId } else { 0 }
        $covers = @()
        if ($gameId -gt 0) {
            if ($Session.CoverCache.ContainsKey($gameId)) {
                # Served from this session's cache, no API call needed.
                $covers = $Session.CoverCache[$gameId]
            } else {
                try {
                    foreach ($c in @(Get-GameCovers -ApiKey $Session.Ctx.ApiKey -GameId $gameId -Category $Session.Ctx.Category -CoversPerGame $Session.Ctx.TopN)) {
                        $covers += @{ url = [string]$c.Url; thumb = [string]$c.Thumb; score = [int]$c.Score }
                    }
                    $Session.CoverCache[$gameId] = $covers
                } catch { }
            }
        }
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true; covers = $covers })
        return
    }

    if ($path -eq '/api/scan-step' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $i = 0
        if ($body -and $null -ne $body.i) { $i = [int]$body.i }
        $result = Step-WebScan -Session $Session -Index $i
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe $result)
        return
    }

    if ($path -eq '/api/apply-begin' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $result = Start-WebApply -Session $Session -Choices $body
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe $result)
        return
    }

    if ($path -eq '/api/apply-step' -and $method -eq 'POST') {
        $bodyText = Read-RequestBody -Context $Context
        $body = $null
        try { $body = $bodyText | ConvertFrom-Json } catch { }
        $i = 0
        if ($body -and $null -ne $body.i) { $i = [int]$body.i }
        $result = Step-WebApply -Session $Session -Index $i
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe $result)
        return
    }

    if ($path -eq '/api/history' -and $method -eq 'POST') {
        $h = @(Get-History -Root $Session.Root -Top 200)
        Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $true; entries = $h })
        return
    }

    # Unknown route
    Send-HttpResponse -Context $Context -Body (ConvertTo-JsonSafe @{ ok = $false; error = 'Not found' }) -StatusCode 404
}

function Start-WebScan {
    <#
        Begins a chunked scan. Reads the folder, builds the shortcut
        list and the unique game-name queue, and returns the total
        count so the browser can drive scan-step one game at a time
        (live progress, no background threads).

        Optional filter:
          -OnlyNew   : keep only games not seen in this folder before
                       (new-game detection).
    #>
    param(
        [Parameter(Mandatory)]$Session,
        [bool]$OnlyNew = $false
    )

    $ctx = $Session.Ctx
    Write-Log "Web scan: $($ctx.Folder) (OnlyNew=$OnlyNew)" 'INFO'

    $shortcuts = @(Get-Shortcuts -Folder $ctx.Folder)
    if ($shortcuts.Count -eq 0) {
        return @{ ok = $false; error = 'No .lnk shortcuts found in that folder.' }
    }
    foreach ($s in $shortcuts) {
        if ($s.Status -ne 'Failed') { $s.NormalizedName = Get-NormalizedGameName -Name $s.Name }
    }

    if ($OnlyNew) {
        $known = Get-KnownGames -Root $Session.Root
        $key = ([string]$ctx.Folder).ToLowerInvariant()
        $prev = @()
        if ($known.ContainsKey($key)) { $prev = @($known[$key]) }
        if ($prev.Count -gt 0) {
            $shortcuts = @($shortcuts | Where-Object { $prev -notcontains ([string]$_.NormalizedName) })
        }
        if ($shortcuts.Count -eq 0) {
            return @{ ok = $false; error = 'No new games since your last visit.' }
        }
    }

    $Session.Shortcuts = $shortcuts

    $uniqueNames = @($shortcuts | Where-Object { $_.Status -ne 'Failed' } |
        ForEach-Object { [string]$_.NormalizedName } | Sort-Object -Unique)

    $Session.Names = $uniqueNames
    $Session.Pending = @()

    return @{
        ok     = $true
        folder = [string]$ctx.Folder
        count  = $shortcuts.Count
        total  = $uniqueNames.Count
    }
}

function Step-WebScan {
    <#
        Resolves ONE game (zero-based index) using the FAST path:
        one search + one artwork call (only the best game's covers).
        Runner-up games are returned as names+scores only (no covers)
        so the browser's "wrong game" screen opens instantly and
        fetches covers per game on click.
    #>
    param(
        [Parameter(Mandatory)]$Session,
        [Parameter(Mandatory)][int]$Index
    )

    $ctx = $Session.Ctx
    $names = @($Session.Names)
    $total = $names.Count

    if ($Index -lt 0 -or $Index -ge $total) {
        return @{ ok = $true; done = $true; total = $total; current = $total }
    }

    $name = [string]$names[$Index]
    try {
        $fast = Get-GameMatchFast -ApiKey $ctx.ApiKey -Query $name -Category $ctx.Category -CoversPerGame $ctx.TopN
    } catch [System.UnauthorizedAccessException] {
        return @{ ok = $false; error = 'SteamGridDB rejected the API key.' }
    } catch {
        $fast = $null
    }

    $safe = Get-SafeFileName -Name $name
    $icoPath = Join-Path $ctx.IconsDir "$safe.ico"

    # Build the JSON item. "sections" carries ONE section (the best
    # game with covers). candidateGames carries the lightweight list.
    $jsonSections = @()
    $candidateGames = @()
    $confident = $false
    $autoConfident = $false
    $topScore = 0

    if ($null -ne $fast -and $null -ne $fast.best) {
        $confident = [bool]$fast.confident
        # Auto mode is intentionally permissive: trust the #1 ranked
        # match unless its score is genuinely low. Wrong picks can be
        # fixed afterwards with "Change specific icons", so we do NOT
        # stop for borderline-but-likely matches.
        if (@($fast.candidateGames).Count -gt 0) { $topScore = [int]([double]$fast.candidateGames[0].Score * 100) }
        if (@($fast.best.Covers).Count -gt 0 -and $topScore -ge 55) { $autoConfident = $true }
        $covers = @()
        foreach ($c in @($fast.best.Covers)) {
            $covers += @{ url = [string]$c.Url; thumb = [string]$c.Thumb; score = [int]$c.Score }
        }
        $jsonSections += @{
            gameId   = [int]$fast.best.GameId
            gameName = [string]$fast.best.GameName
            year     = [int]$fast.best.Year
            covers   = $covers
        }
        foreach ($g in @($fast.candidateGames)) {
            $candidateGames += @{
                gameId = [int]$g.GameId; gameName = [string]$g.GameName
                year = [int]$g.Year; score = [int]([double]$g.Score * 100)
            }
        }
    }

    $itemObj = [PSCustomObject]@{
        Index    = ($Index + 1)
        Name     = [string]$name
        Safe     = [string]$safe
        IcoPath  = [string]$icoPath
        Sections = $jsonSections   # filled/extended by the browser as needed
    }
    $Session.Pending += $itemObj

    $item = @{
        index          = ($Index + 1)
        name           = [string]$name
        sections       = $jsonSections
        candidateGames = $candidateGames
        confident      = $confident
        autoConfident  = $autoConfident
        topScore       = $topScore
    }

    # Remembered choice? Mark it so the browser can offer to skip /
    # auto-apply previously picked covers.
    try {
        if ($ctx.SavedChoices.ContainsKey($name)) {
            $sc = $ctx.SavedChoices[$name]
            $savedUrl = [string]$sc.Url
            if (-not [string]::IsNullOrWhiteSpace($savedUrl)) {
                $item.remembered = $true
                $item.savedUrl = $savedUrl
                $item.savedGameName = [string]$sc.GameName
            }
        }
    } catch { }

    return @{
        ok      = $true
        done    = ($Index + 1 -ge $total)
        current = ($Index + 1)
        total   = $total
        label   = $name
        item    = $item
    }
}

function Start-WebApply {
    <#
        Stores the browser's choices on the session and returns the
        total number of shortcuts so the browser can drive apply-step.
        The actual download/build/apply happens in one pipeline call
        on the final step (the pipeline already parallelizes), but we
        report coarse phase progress to the browser.
    #>
    param(
        [Parameter(Mandatory)]$Session,
        $Choices
    )
    $pending = @($Session.Pending)
    if ($pending.Count -eq 0) {
        return @{ ok = $false; error = 'Nothing to apply. Scan first.' }
    }
    $Session | Add-Member -NotePropertyName Choices -NotePropertyValue $Choices -Force
    return @{ ok = $true; total = @($Session.Shortcuts).Count }
}

function Step-WebApply {
    <#
        Builds resolutions from the explicit picks the browser sends
        (each pick carries url + gameId + gameName, so no re-derivation
        from sections is needed), then runs the standard apply pipeline
        and returns the final report.
    #>
    param(
        [Parameter(Mandatory)]$Session,
        [Parameter(Mandatory)][int]$Index
    )

    $ctx = $Session.Ctx
    $pending = @($Session.Pending)
    $shortcuts = @($Session.Shortcuts)
    $Choices = $Session.Choices

    # index(string) -> @{ url; gameId; gameName }
    $pickMap = @{}
    if ($Choices -and $Choices.picks) {
        foreach ($p in @($Choices.picks)) {
            if ($null -ne $p.index) {
                $pickMap[[string]([int]$p.index)] = @{
                    Url      = [string]$p.url
                    GameId   = [int]$p.gameId
                    GameName = [string]$p.gameName
                }
            }
        }
    }

    $resolutions = @{}
    foreach ($entry in $pending) {
        $key = [string]$entry.Index
        $nm = [string]$entry.Name

        if (-not $pickMap.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($pickMap[$key].Url)) {
            # No usable pick: placeholder cover keeps the run complete.
            $resolutions[$nm] = @{ Placeholder = $true; IcoPath = [string]$entry.IcoPath; GameName = $nm; Failed = $false; Cached = $false }
            continue
        }

        $pick = $pickMap[$key]
        $resolutions[$nm] = New-ArtworkResolution -Ctx $ctx -Name $nm -Safe ([string]$entry.Safe) -IcoPath ([string]$entry.IcoPath) `
            -Url ([string]$pick.Url) -Kind ([string]$ctx.Category) -GameName ([string]$pick.GameName) -Score 1.0 -DeleteRaw $true

        if ($pick.GameId -gt 0) { $ctx.Overrides[$nm] = [int]$pick.GameId }
        $ctx.SavedChoices[$nm] = [PSCustomObject]@{
            Url      = [string]$pick.Url
            GameName = [string]$pick.GameName
            Kind     = [string]$ctx.Category
            PickedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm')
        }
    }
    Save-Overrides -Root $ctx.Root -Overrides $ctx.Overrides
    Save-SavedChoices -Root $ctx.Root -Choices $ctx.SavedChoices

    Invoke-ApplyPipeline -Ctx $ctx -Shortcuts $shortcuts -Resolutions $resolutions -Force $true

    # Record what we changed into the history log (newest first).
    try {
        $now = Get-Date -Format 'yyyy-MM-dd HH:mm'
        $histEntries = @()
        foreach ($s in $shortcuts) {
            if ($s.Status -eq 'Updated') {
                $hn = [string]$s.NormalizedName
                $hg = ''; $hu = ''
                if ($ctx.SavedChoices.ContainsKey($hn)) {
                    $hg = [string]$ctx.SavedChoices[$hn].GameName
                    $hu = [string]$ctx.SavedChoices[$hn].Url
                }
                $histEntries += @{ name = [string]$s.Name; game = $hg; url = $hu; date = $now }
            }
        }
        if ($histEntries.Count -gt 0) { Add-HistoryEntries -Root $ctx.Root -Entries $histEntries }
    } catch { }

    # Build a per-shortcut detail list so the report stats are clickable
    # in the browser (show the games behind each number, with covers).
    $details = @()
    foreach ($s in $shortcuts) {
        $nm = [string]$s.NormalizedName
        $isPlaceholder = ($s.Status -eq 'Updated' -and $s.Detail -eq '-> placeholder cover')
        $cat = 'failed'
        if ($s.Status -eq 'Updated') { $cat = if ($isPlaceholder) { 'placeholder' } else { 'matched' } }
        elseif ($s.Status -eq 'Skipped') { $cat = 'skipped' }

        $thumb = ''
        $gameName = ''
        if ($ctx.SavedChoices.ContainsKey($nm)) {
            $thumb = [string]$ctx.SavedChoices[$nm].Url
            $gameName = [string]$ctx.SavedChoices[$nm].GameName
        }
        # Find this shortcut's pending index so the browser can re-pick it
        $pendIdx = 0
        foreach ($pe in $pending) { if ([string]$pe.Name -eq $nm) { $pendIdx = [int]$pe.Index; break } }

        $details += @{
            index    = $pendIdx
            name     = [string]$s.Name
            game     = $gameName
            thumb    = $thumb
            category = $cat
        }
    }

    $total       = @($shortcuts).Count
    $updated     = @($shortcuts | Where-Object { $_.Status -eq 'Updated' }).Count
    $placeholder = @($shortcuts | Where-Object { $_.Status -eq 'Updated' -and $_.Detail -eq '-> placeholder cover' }).Count
    $skipped     = @($shortcuts | Where-Object { $_.Status -eq 'Skipped' }).Count
    $failed      = @($shortcuts | Where-Object { $_.Status -eq 'Failed' }).Count
    $matched     = $updated - $placeholder

    return @{
        ok = $true
        done = $true
        report = @{
            total = $total; matched = $matched; updated = $updated
            placeholder = $placeholder; skipped = $skipped; failed = $failed
            details = $details
        }
    }
}
function Start-WebScanFiles {
    <#
        Change Icons: begins a chunked scan limited to the explicit
        list of .lnk files the user picked. Same step protocol as the
        full scan (scan-step drives the rest), so the browser code is
        shared. Returns the unique-name total.
    #>
    param(
        [Parameter(Mandatory)]$Session,
        [Parameter(Mandatory)][string[]]$Files
    )

    if ($Files.Count -eq 0) {
        return @{ ok = $false; error = 'No files selected.' }
    }

    $shortcuts = @(Get-ShortcutsFromPaths -Paths $Files)
    if ($shortcuts.Count -eq 0) {
        return @{ ok = $false; error = 'None of the selected files were readable shortcuts.' }
    }
    foreach ($s in $shortcuts) {
        if ($s.Status -ne 'Failed') { $s.NormalizedName = Get-NormalizedGameName -Name $s.Name }
    }

    # Remember the folder of the first picked file
    try {
        $folder = Split-Path -Parent $Files[0]
        if (Test-Path $folder) {
            $Session.Ctx.Folder = $folder
            $Session.Ctx.Settings.LastFolder = $folder
            Save-Settings -Root $Session.Root -Settings $Session.Ctx.Settings
        }
    } catch { }

    $Session.Shortcuts = $shortcuts
    $uniqueNames = @($shortcuts | Where-Object { $_.Status -ne 'Failed' } |
        ForEach-Object { [string]$_.NormalizedName } | Sort-Object -Unique)
    $Session.Names = $uniqueNames
    $Session.Pending = @()

    return @{
        ok    = $true
        count = $shortcuts.Count
        total = $uniqueNames.Count
    }
}

# ---------------- v6.4: async native dialogs (non-blocking) ----------------

function Start-AsyncDialog {
    <#
        Launches a native folder or file picker on its OWN STA thread
        so the HTTP server thread is never blocked. The result lands
        in $Dialog (synchronized) which the browser polls via
        /api/dialog-status. This fixes the "everything freezes then
        all windows open at once" bug: the server keeps answering
        requests while the Windows dialog is open.

        $Kind = 'folder' or 'files'.
    #>
    param(
        [Parameter(Mandatory)]$Dialog,
        [Parameter(Mandatory)][ValidateSet('folder','files')][string]$Kind,
        [string]$InitialFolder = ''
    )

    if ($Dialog.status -eq 'running') { return }

    $Dialog.status = 'running'
    $Dialog.kind   = $Kind
    $Dialog.folder = ''
    $Dialog.files  = @()

    $worker = {
        param($Dialog, $Kind, $InitialFolder)

        try {
            if ($Kind -eq 'folder') {
                # Shell folder browser via a topmost owner form
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                Add-Type -AssemblyName System.Drawing -ErrorAction Stop
                $owner = New-Object System.Windows.Forms.Form
                $owner.TopMost = $true; $owner.ShowInTaskbar = $false
                $owner.Opacity = 0; $owner.Width = 1; $owner.Height = 1
                $owner.StartPosition = 'CenterScreen'
                $owner.Add_Shown({ $owner.Activate() })
                $owner.Show(); $owner.Activate()

                $fb = New-Object System.Windows.Forms.FolderBrowserDialog
                $fb.Description = 'Select your game shortcuts folder'
                $fb.ShowNewFolderButton = $false
                if (-not [string]::IsNullOrWhiteSpace($InitialFolder) -and (Test-Path $InitialFolder)) {
                    $fb.SelectedPath = $InitialFolder
                }
                $res = $fb.ShowDialog($owner)
                if ($res -eq [System.Windows.Forms.DialogResult]::OK) { $Dialog.folder = [string]$fb.SelectedPath }
                $owner.Close(); $owner.Dispose()
            }
            else {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                Add-Type -AssemblyName System.Drawing -ErrorAction Stop
                $owner = New-Object System.Windows.Forms.Form
                $owner.TopMost = $true; $owner.ShowInTaskbar = $false
                $owner.Opacity = 0; $owner.Width = 1; $owner.Height = 1
                $owner.StartPosition = 'CenterScreen'
                $owner.Add_Shown({ $owner.Activate() })
                $owner.Show(); $owner.Activate()

                $ofd = New-Object System.Windows.Forms.OpenFileDialog
                $ofd.Title = 'Select the shortcuts whose icons you want to change (Ctrl+click for multiple)'
                $ofd.Filter = 'Shortcuts (*.lnk)|*.lnk|All files (*.*)|*.*'
                $ofd.Multiselect = $true
                $ofd.CheckFileExists = $true
                if (-not [string]::IsNullOrWhiteSpace($InitialFolder) -and (Test-Path $InitialFolder)) {
                    $ofd.InitialDirectory = $InitialFolder
                }
                $res = $ofd.ShowDialog($owner)
                if ($res -eq [System.Windows.Forms.DialogResult]::OK) { $Dialog.files = @($ofd.FileNames) }
                $owner.Close(); $owner.Dispose()
            }
        } catch {
            # leave results empty on failure
        } finally {
            $Dialog.status = 'done'
        }
    }

    $ps = [PowerShell]::Create()
    $rs = [RunspaceFactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions = 'ReuseThread'
    $rs.Open()
    $ps.Runspace = $rs
    [void]$ps.AddScript($worker).AddArgument($Dialog).AddArgument($Kind).AddArgument($InitialFolder)
    $Dialog.handle = $ps.BeginInvoke()
    $Dialog.ps = $ps
}

function Open-FolderLargeIcons {
    <#
        Opens a folder in Explorer and switches its view to Large
        Icons so the user sees their new game shelf right away.
    #>
    param([Parameter(Mandatory)][string]$Folder)

    if ([string]::IsNullOrWhiteSpace($Folder) -or -not (Test-Path $Folder)) { return }

    try {
        $shell = New-Object -ComObject Shell.Application
        $shell.Open($Folder)
        Start-Sleep -Milliseconds 700

        # Find the just-opened window and set its view to Large Icons.
        foreach ($w in @($shell.Windows())) {
            try {
                $loc = [string]$w.Document.Folder.Self.Path
                if ($loc -eq $Folder) {
                    # IconSize 96 = Large Icons (48 = medium, 256 = extra large)
                    $w.Document.CurrentViewMode = 1   # 1 = icons view
                    $w.Document.IconSize = 96
                    break
                }
            } catch { }
        }
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    } catch {
        # Fallback: plain open
        try { Start-Process explorer.exe -ArgumentList "`"$Folder`"" } catch { }
    }
}
