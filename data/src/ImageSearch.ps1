# ============================================================
# ImageSearch.ps1 - multi-provider web image search for app icons
# v6.36
# Structured brand-icon search plus semantically-filtered image-engine candidates.
# Best-effort parser for public Google Images / Yandex Images result pages.
# Official API mode is not required; if providers block automated requests,
# the caller preserves the embedded program icon and keeps manual search available.
# ============================================================

function ConvertTo-ImageSearchDecodedHtml {
    param([Parameter(Mandatory)][string]$Html)
    $s = [System.Net.WebUtility]::HtmlDecode($Html)
    $replacements = @(
        @('\u003a', ':'), @('\u003d', '='), @('\u0026', '&'), @('\u002f', '/'),
        @('\u003f', '?'), @('\u0025', '%'), @('\u0027', "'"), @('\u0022', '"'),
        @('\u003c', '<'), @('\u003e', '>'), @('\x3a', ':'), @('\x3d', '='),
        @('\x26', '&'), @('\x2f', '/'), @('\/', '/')
    )
    foreach ($pair in $replacements) { $s = $s.Replace([string]$pair[0], [string]$pair[1]) }
    $s = $s.Replace('&amp;', '&')
    return $s
}

function Get-ImageSearchDimensionHint {
    param([string]$Html, [int]$Index)
    $start = [Math]::Max(0, $Index - 500)
    $length = [Math]::Min($Html.Length - $start, 1000)
    if ($length -le 0) { return @{ Width = 0; Height = 0; Context = '' } }
    $context = $Html.Substring($start, $length)
    $w = 0; $h = 0
    foreach ($pattern in @('"(?:ow|img_width|imageWidth|width)"\s*:\s*"?(\d{2,5})', '"w"\s*:\s*"?(\d{2,5})')) {
        $m = [regex]::Match($context, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { $w = [int]$m.Groups[1].Value; break }
    }
    foreach ($pattern in @('"(?:oh|img_height|imageHeight|height)"\s*:\s*"?(\d{2,5})', '"h"\s*:\s*"?(\d{2,5})')) {
        $m = [regex]::Match($context, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { $h = [int]$m.Groups[1].Value; break }
    }
    return @{ Width = $w; Height = $h; Context = $context }
}

function Get-ProgramIconIdentityContext {
    <# Resolve the actual application identity from a shortcut target's PE version metadata. #>
    param([Parameter(Mandatory)]$Session, [Parameter(Mandatory)][string]$Name)
    $result = [ordered]@{ ProductName=''; CompanyName=''; FileDescription=''; TargetPath='' }
    $items = @($Session.Shortcuts | Where-Object {
        ([string]$_.NormalizedName -ieq $Name -or [string]$_.Name -ieq $Name) -and $_.Status -ne 'Failed'
    })
    foreach ($item in $items) {
        $paths = New-Object System.Collections.Generic.List[string]
        foreach ($raw in @([string]$item.Target, [string]$item.IconLocation)) {
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }
            $candidate = $raw.Trim()
            if ($candidate -match '^"(?<p>[^"]+\.exe|[^"]+\.dll|[^"]+\.icl)"') { $candidate = $Matches.p }
            else { $candidate = ($candidate -split ',')[0].Trim().Trim('"') }
            if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf) -and -not $paths.Contains($candidate)) {
                $paths.Add($candidate)
            }
        }
        foreach ($path in $paths) {
            if ([System.IO.Path]::GetExtension($path).ToLowerInvariant() -notin @('.exe','.dll','.icl')) { continue }
            try {
                $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path)
                if ([string]::IsNullOrWhiteSpace($result.ProductName) -and -not [string]::IsNullOrWhiteSpace([string]$vi.ProductName)) { $result.ProductName = ([string]$vi.ProductName).Trim() }
                if ([string]::IsNullOrWhiteSpace($result.CompanyName) -and -not [string]::IsNullOrWhiteSpace([string]$vi.CompanyName)) { $result.CompanyName = ([string]$vi.CompanyName).Trim() }
                if ([string]::IsNullOrWhiteSpace($result.FileDescription) -and -not [string]::IsNullOrWhiteSpace([string]$vi.FileDescription)) { $result.FileDescription = ([string]$vi.FileDescription).Trim() }
                if ([string]::IsNullOrWhiteSpace($result.TargetPath)) { $result.TargetPath = $path }
            } catch { }
            if (-not [string]::IsNullOrWhiteSpace($result.ProductName) -and -not [string]::IsNullOrWhiteSpace($result.CompanyName)) { break }
        }
        if (-not [string]::IsNullOrWhiteSpace($result.ProductName)) { break }
    }
    foreach ($key in @('ProductName','CompanyName','FileDescription')) {
        if ([string]$result[$key] -match '^(?i)(application|program|unknown|windows application|file description|product name|company name|n/?a)$') { $result[$key] = '' }
    }
    return [PSCustomObject]$result
}

function Get-IconifyBrandSemanticScore {
    param([Parameter(Mandatory)][string]$IconId, [Parameter(Mandatory)][string[]]$Queries)
    $slug = ($IconId -split ':',2)[-1].ToLowerInvariant()
    $slugCompact = [regex]::Replace($slug, '[^a-z0-9]', '')
    $best = 0
    $stop = @('icon','icons','logo','logos','app','application','program','software','windows','desktop','client','launcher','setup','install','stable','portable','official','png','svg','transparent','high','resolution','image','images','64','32','x64','x86','arm64','exe','dll','the','for','and','256','512','1024','1920','2k','4k')
    $generic = @('media','player','browser','editor','viewer','manager','suite','tool','tools')
    foreach ($q in $Queries) {
        if ([string]::IsNullOrWhiteSpace($q)) { continue }
        $rawTokens = @([regex]::Matches($q.ToLowerInvariant(), '[a-z0-9]{2,}') | ForEach-Object { $_.Value } | Where-Object { $_ -notin $stop } | Select-Object -Unique)
        $tokens = @($rawTokens | Where-Object { $_ -notin $generic })
        # Keep generic product words only when the name has no more distinctive token
        # (e.g. Windows Media Player), but don't let them dilute a specific brand such as VLC.
        if ($tokens.Count -eq 0) { $tokens = $rawTokens }
        if ($tokens.Count -eq 0) { continue }
        $compact = [regex]::Replace(($tokens -join ''), '[^a-z0-9]', '')
        $hit = 0
        foreach ($token in $tokens) { if ($slug -match [regex]::Escape($token)) { $hit++ } }
        $ratio = $hit / [double]$tokens.Count
        $score = 0
        if ($compact.Length -ge 3 -and ($slugCompact -eq $compact -or $slugCompact.Contains($compact))) { $score = 98 }
        elseif ($ratio -ge 0.99) { $score = 91 }
        elseif ($ratio -ge 0.75) { $score = 82 }
        elseif ($ratio -ge 0.50) { $score = 68 }
        elseif ($ratio -gt 0) { $score = 52 }
        if ($tokens.Count -eq 1 -and $hit -eq 1) { $score = [Math]::Max($score, 90) }
        if ($score -gt $best) { $best = $score }
    }
    return [int]$best
}

function Get-IconifyBrandIconCandidates {
    <# Structured search of curated brand/software icon sets. URLs are SVGs; the browser scan rasterizes these to local PNG before the normal ICO pipeline. #>
    param([Parameter(Mandatory)][string[]]$Queries, [int]$MaxResults=12)
    $queries = @($Queries | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Select-Object -Unique | Select-Object -First 3)
    if ($queries.Count -eq 0) { return @() }
    try { Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue } catch { }
    $client = $null
    $resultList = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $prefixes = 'logos,simple-icons,devicon,skill-icons,cib,fa-brands'
    try {
        $client = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromSeconds(4)
        $null = $client.DefaultRequestHeaders.UserAgent.TryParseAdd('Game-Icons-Studio/6.36 (local desktop utility)')
        foreach ($q in $queries) {
            try {
                $url = 'https://api.iconify.design/search?query=' + [uri]::EscapeDataString($q) + '&limit=64&prefixes=' + [uri]::EscapeDataString($prefixes)
                $response = $client.GetAsync($url).GetAwaiter().GetResult()
                if (-not $response.IsSuccessStatusCode) { $response.Dispose(); continue }
                $jsonText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                $response.Dispose()
                $payload = $jsonText | ConvertFrom-Json -ErrorAction Stop
                foreach ($idValue in @($payload.icons)) {
                    $id = [string]$idValue
                    if ($id -notmatch '^([a-z0-9-]+):([a-z0-9-]+)$') { continue }
                    $prefix = $Matches[1]; $iconName = $Matches[2]
                    if ($prefix -notin @('logos','simple-icons','devicon','skill-icons','cib','fa-brands')) { continue }
                    $score = Get-IconifyBrandSemanticScore -IconId $id -Queries $queries
                    if ($score -lt 65) { continue }
                    $pathPrefix = [uri]::EscapeDataString($prefix)
                    $pathIcon = [uri]::EscapeDataString($iconName)
                    $svgUrl = "https://api.iconify.design/$pathPrefix/$pathIcon.svg"
                    $key = $id.ToLowerInvariant()
                    if ($seen.ContainsKey($key)) {
                        if ($score -gt [int]$seen[$key].Score) { $seen[$key].Score = $score }
                        continue
                    }
                    $candidate = [PSCustomObject]@{
                        Url=$svgUrl; Thumb=$svgUrl; Source="Iconify / $prefix"; Title=($prefix + ' / ' + $iconName.Replace('-',' '));
                        Width=256; Height=256; Score=[int]$score; SearchPage=('https://icon-sets.iconify.design/' + $prefix + '/')
                    }
                    $seen[$key] = $candidate
                    $resultList.Add($candidate)
                }
            } catch { Write-Log "Iconify structured search failed for '$q': $($_.Exception.Message)" 'DEBUG' }
        }
    } catch { Write-Log "Iconify search setup failed: $($_.Exception.Message)" 'DEBUG' }
    finally { if ($client) { $client.Dispose() } }
    return @($resultList | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression='Title';Descending=$false} | Select-Object -First ([Math]::Max(1,$MaxResults)))
}

function Get-ImageCandidateQualityScore {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Query,
        [string]$Title = '',
        [string]$Context = '',
        [int]$Width = 0,
        [int]$Height = 0,
        [string]$Provider = ''
    )
    $score = 30
    $uri = $null
    try { $uri = [uri]$Url } catch { return 0 }
    if ($uri.Scheme -notin @('http','https')) { return 0 }
    $hostName = [string]$uri.Host
    $path = [string]$uri.AbsolutePath
    $urlLower = ($Url + ' ' + $Title).ToLowerInvariant()
    $ext = [System.IO.Path]::GetExtension(($path -split '\?')[0]).ToLowerInvariant()
    switch ($ext) {
        '.png'  { $score += 9 }
        '.ico'  { $score += 8 }
        '.jpg'  { $score += 6 }
        '.jpeg' { $score += 6 }
        '.bmp'  { $score += 4 }
        '.gif'  { $score += 1 }
        '.webp' { $score += 1 }
        '.svg'  { $score += 3 }
        default { $score -= 2 }
    }
    if ($urlLower -match 'icon|logo|brand|app.?mark|application') { $score += 5 }
    if ($urlLower -match 'official|press.?kit|brand.?asset') { $score += 4 }
    if ($urlLower -match 'encrypted-tbn|thumbnail|thumb|preview|small|/tbn|/thumbs?/') { $score -= 12 }
    if ($hostName -match 'google|gstatic|yandex') {
        if ($hostName -match 'encrypted-tbn|gstatic|avatars\.mds\.yandex\.net') { $score -= 8 }
        elseif ($hostName -match 'google\.com|yandex\.(com|ru|tr)$') { return 0 }
    }

    # Crucial v6.35 correction: do NOT search the surrounding HTML blob for query terms.
    # Search pages mention the requested app many times even when a nearby URL is unrelated.
    $stop = @('icon','icons','logo','logos','app','application','program','software','windows','desktop','client','launcher','setup','install','official','png','svg','transparent','high','resolution','image','images','64','32','x64','x86','exe','dll','the','for','and','256','512','1024','1920','2k','4k')
    $rawTokens = @([regex]::Matches($Query.ToLowerInvariant(), '[a-z0-9]{2,}') | ForEach-Object { $_.Value } | Where-Object { $_ -notin $stop } | Select-Object -Unique)
    $generic = @('media','player','browser','editor','viewer','manager','suite','tool','tools')
    $tokens = @($rawTokens | Where-Object { $_ -notin $generic })
    if ($tokens.Count -eq 0) { $tokens = $rawTokens }
    if ($tokens.Count -gt 0) {
        $matched = 0
        foreach ($word in $tokens) { if ($urlLower.Contains($word)) { $matched++ } }
        $ratio = $matched / [double]$tokens.Count
        if ($ratio -ge 0.99) { $score += 36 }
        elseif ($ratio -ge 0.66) { $score += 23 }
        elseif ($ratio -ge 0.34) { $score += 10 }
        elseif ($matched -eq 0) { $score -= 38 }
        else { $score -= 18 }
        $normQ = [regex]::Replace(($tokens -join ''), '[^a-z0-9]', '')
        $normT = [regex]::Replace($urlLower, '[^a-z0-9]', '')
        if ($normQ.Length -ge 4 -and $normT.Contains($normQ)) { $score += 12 }
    } else { $score -= 8 }

    if ($Width -gt 0 -and $Height -gt 0) {
        $ratio = [double][Math]::Min($Width, $Height) / [double][Math]::Max($Width, $Height)
        if ($ratio -ge 0.94) { $score += 10 }
        elseif ($ratio -ge 0.82) { $score += 5 }
        elseif ($ratio -lt 0.65) { $score -= 8 }
        $minSide = [Math]::Min($Width, $Height)
        if ($minSide -ge 1024) { $score += 12 }
        elseif ($minSide -ge 512) { $score += 9 }
        elseif ($minSide -ge 256) { $score += 5 }
        elseif ($minSide -lt 128) { $score -= 15 }
    }
    if ($Provider -eq 'Google') { $score += 1 }
    if ($Provider -eq 'Yandex') { $score += 1 }
    return [int][Math]::Max(0, [Math]::Min(100, $score))
}

function Get-ImageSearchCandidatesFromHtml {
    param(
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][ValidateSet('Google','Yandex')][string]$Provider,
        [Parameter(Mandatory)][string]$Query,
        [int]$MaxResults = 12,
        [string]$SearchPage = ''
    )
    $decoded = ConvertTo-ImageSearchDecodedHtml -Html $Html
    $found = New-Object System.Collections.Generic.List[object]
    $seen = @{}

    # Original-image fields embedded in result metadata are preferred over small thumbnails.
    $specialPattern = '(?is)"(?:ou|img_href|imgHref|origUrl|originalUrl|image_url|imageUrl|imageurl)"\s*:\s*"(?<url>https?://[^"<>\s]+)"'
    foreach ($m in [regex]::Matches($decoded, $specialPattern)) {
        $url = [string]$m.Groups['url'].Value
        $url = $url.TrimEnd(',', ';', '.', ')', ']', '}')
        $uri = $null
        if (-not [uri]::TryCreate($url, [System.UriKind]::Absolute, [ref]$uri)) { continue }
        if ($uri.Scheme -notin @('http','https')) { continue }
        if ($uri.Host -match '^(www\.)?(google\.[^/]+|yandex\.(com|ru|tr))$') { continue }
        if ($url -match '(?i)\.(svg|webp|avif)(\?|$)') { continue }
        $key = $url.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $hint = Get-ImageSearchDimensionHint -Html $decoded -Index $m.Index
        $title = ''
        $titleMatch = [regex]::Match($hint.Context, '(?is)"(?:pt|pageTitle|title|alt)"\s*:\s*"(?<t>[^"\r\n]{1,180})"')
        if ($titleMatch.Success) { $title = [System.Net.WebUtility]::HtmlDecode([string]$titleMatch.Groups['t'].Value) }
        $score = Get-ImageCandidateQualityScore -Url $url -Query $Query -Title $title -Context $hint.Context -Width $hint.Width -Height $hint.Height -Provider $Provider
        if ($score -lt 34) { continue }
        $found.Add([PSCustomObject]@{ Url=$url; Thumb=$url; Source="$Provider Images"; Title=$title; Width=[int]$hint.Width; Height=[int]$hint.Height; Score=$score; SearchPage=$SearchPage })
        $seen[$key] = $true
    }

    # Visible image URLs are a fallback. Thumbnail CDNs score lower than original-size artwork.
    foreach ($tagMatch in [regex]::Matches($decoded, '(?is)<img\b[^>]*>')) {
        $tag = [string]$tagMatch.Value
        $title = ''
        $altMatch = [regex]::Match($tag, '(?is)\b(?:alt|title)\s*=\s*["''](?<v>[^"'']{0,180})["'']')
        if ($altMatch.Success) { $title = [System.Net.WebUtility]::HtmlDecode($altMatch.Groups['v'].Value) }
        $urlMatches = [regex]::Matches($tag, '(?is)\b(?:src|data-src|data-original|data-original-src|data-iurl|data-lazy-src)\s*=\s*["''](?<u>https?://[^"'']+)["'']')
        foreach ($um in $urlMatches) {
            $url = [string]$um.Groups['u'].Value
            if ($url -match '(?i)^https?://(www\.)?(google\.[^/]+|yandex\.(com|ru|tr))/') { continue }
            if ($url -match '(?i)^data:|\.(svg|webp|avif)(\?|$)') { continue }
            $uri = $null
            if (-not [uri]::TryCreate($url, [System.UriKind]::Absolute, [ref]$uri)) { continue }
            $key = $url.ToLowerInvariant()
            if ($seen.ContainsKey($key)) { continue }
            $hint = Get-ImageSearchDimensionHint -Html $decoded -Index $tagMatch.Index
            $score = Get-ImageCandidateQualityScore -Url $url -Query $Query -Title $title -Context $hint.Context -Width $hint.Width -Height $hint.Height -Provider $Provider
            if ($score -lt 34) { continue }
            $found.Add([PSCustomObject]@{ Url=$url; Thumb=$url; Source="$Provider Images"; Title=$title; Width=[int]$hint.Width; Height=[int]$hint.Height; Score=$score; SearchPage=$SearchPage })
            $seen[$key] = $true
        }
    }

    # Generic URL extraction catches newer JS-embedded result payloads whose field names change.
    foreach ($m in [regex]::Matches($decoded, '(?i)https?://[^\s"''<>\\]+')) {
        $url = [string]$m.Value
        $url = $url.TrimEnd(',', ';', '.', ')', ']', '}', ':')
        if ($url -match '(?i)^(https?://)?(www\.)?(google\.[^/]+|yandex\.(com|ru|tr))(/|$)') { continue }
        if ($url -match '(?i)^data:|\.(svg|webp|avif)(\?|$)') { continue }
        $uri = $null
        if (-not [uri]::TryCreate($url, [System.UriKind]::Absolute, [ref]$uri)) { continue }
        if ($uri.Scheme -notin @('http','https')) { continue }
        $path = [string]$uri.AbsolutePath
        $isLikelyImage = ($path -match '(?i)\.(png|jpe?g|gif|bmp|ico)(\.[a-z0-9]+)?$') -or ($uri.Host -match '(?i)image|img|photo|avatar|cdn|static|media') -or ($path -match '(?i)/get-images?/|/get/|/images?/|/icons?/|/logo')
        if (-not $isLikelyImage) { continue }
        $key = $url.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $hint = Get-ImageSearchDimensionHint -Html $decoded -Index $m.Index
        $nearTitle = ''
        $titleMatch = [regex]::Match($hint.Context, '(?is)"(?:pt|pageTitle|title|alt)"\s*:\s*"(?<t>[^"\r\n]{1,180})"')
        if ($titleMatch.Success) { $nearTitle = [System.Net.WebUtility]::HtmlDecode([string]$titleMatch.Groups['t'].Value) }
        $score = Get-ImageCandidateQualityScore -Url $url -Query $Query -Title $nearTitle -Context $hint.Context -Width $hint.Width -Height $hint.Height -Provider $Provider
        if ($score -lt 34) { continue }
        $found.Add([PSCustomObject]@{ Url=$url; Thumb=$url; Source="$Provider Images"; Title=$nearTitle; Width=[int]$hint.Width; Height=[int]$hint.Height; Score=$score; SearchPage=$SearchPage })
        $seen[$key] = $true
    }

    $ranked = @($found | Sort-Object -Property @(
        @{Expression='Score';Descending=$true},
        @{Expression={ if ($_.Width -gt 0 -and $_.Height -gt 0) { [Math]::Min($_.Width,$_.Height) } else { 0 } };Descending=$true}
    ))
    return @($ranked | Select-Object -First ([Math]::Max(1,$MaxResults)))
}

function Get-OnlineProgramIconCandidates {
    <#
        Queries Google Images and Yandex Images concurrently and returns a merged,
        deduplicated list ordered by square ratio and available resolution hints.
        This is intentionally a best-effort HTML parser because Google has closed
        its Custom Search JSON API to new customers and Yandex API requires a key.
    #>
    param(
        [Parameter(Mandatory)][string]$Query,
        [ValidateSet('both','google','yandex')][string]$Provider = 'both',
        [int]$MaxResults = 16,
        $Session = $null
    )
    $cleanQuery = [regex]::Replace($Query, '[\r\n\t]+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($cleanQuery)) { return @() }
    if ($cleanQuery.Length -gt 160) { $cleanQuery = $cleanQuery.Substring(0,160) }
    # Pull product/company identity from the shortcut's executable metadata where possible.
    $identity = [PSCustomObject]@{ ProductName=''; CompanyName=''; FileDescription=''; TargetPath='' }
    if ($null -ne $Session) { try { $identity = Get-ProgramIconIdentityContext -Session $Session -Name $cleanQuery } catch { } }
    $identityQueries = New-Object System.Collections.Generic.List[string]
    foreach ($q in @([string]$identity.ProductName, $cleanQuery, [string]$identity.FileDescription)) {
        $q = [regex]::Replace($q, '[\r\n\t]+', ' ').Trim()
        if ($q -and -not $identityQueries.Contains($q)) { $identityQueries.Add($q) }
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$identity.CompanyName) -and -not [string]::IsNullOrWhiteSpace([string]$identity.ProductName)) {
        $companyProduct = ([string]$identity.ProductName + ' ' + [string]$identity.CompanyName).Trim()
        if (-not $identityQueries.Contains($companyProduct)) { $identityQueries.Insert(0,$companyProduct) }
    }
    $iconifyQueries = @($identityQueries | Select-Object -First 2)
    # Search provider pages with two focused query shapes. Keep company metadata in the
    # first query when available, but preserve the user's visible shortcut name as a fallback.
    $primaryQuery = if (-not [string]::IsNullOrWhiteSpace([string]$identity.ProductName)) { [string]$identity.ProductName } else { $cleanQuery }
    if (-not [string]::IsNullOrWhiteSpace([string]$identity.CompanyName)) { $primaryQuery = ($primaryQuery + ' ' + [string]$identity.CompanyName).Trim() }
    $queryVariants = @(
        ($primaryQuery + ' official application icon logo png 512'),
        ('"' + $cleanQuery + '" app icon png transparent high resolution')
    ) | Select-Object -Unique
    $searches = New-Object System.Collections.Generic.List[object]
    foreach ($providerName in @('Google','Yandex')) {
        if ($Provider -eq 'google' -and $providerName -ne 'Google') { continue }
        if ($Provider -eq 'yandex' -and $providerName -ne 'Yandex') { continue }
        foreach ($searchQuery in $queryVariants) {
            $encoded = [uri]::EscapeDataString($searchQuery)
            if ($providerName -eq 'Google') {
                $searchUrl = "https://www.google.com/search?tbm=isch&hl=en&safe=active&tbs=isz:l,iar:s&q=$encoded"
            } else {
                $searchUrl = "https://yandex.com/images/search?text=$encoded&isize=large&itype=png"
            }
            $searches.Add([PSCustomObject]@{ Provider=$providerName; Query=$searchQuery; Url=$searchUrl })
        }
    }

    try { Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue } catch { }
    $handler = $null; $client = $null
    $responsePages = New-Object System.Collections.Generic.List[object]
    try {
        $handler = [System.Net.Http.HttpClientHandler]::new()
        $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        $client = [System.Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromSeconds(4)
        $null = $client.DefaultRequestHeaders.UserAgent.TryParseAdd('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36')
        $pending = New-Object System.Collections.Generic.List[object]
        foreach ($search in $searches) {
            try {
                $task = $client.GetAsync([string]$search.Url)
                $pending.Add([PSCustomObject]@{ Provider=$search.Provider; Query=$search.Query; SearchPage=$search.Url; Task=$task })
            } catch { }
        }
        if ($pending.Count -gt 0) {
            $tasks = [System.Threading.Tasks.Task[]]@($pending | ForEach-Object { $_.Task })
            try { [void][System.Threading.Tasks.Task]::WaitAll($tasks, 7000) } catch { }
            foreach ($entry in $pending) {
                if ($entry.Task.Status -ne [System.Threading.Tasks.TaskStatus]::RanToCompletion) { continue }
                $resp = $null
                try {
                    $resp = $entry.Task.Result
                    if (-not $resp.IsSuccessStatusCode) { continue }
                    $ct = ''
                    try { $ct = [string]$resp.Content.Headers.ContentType.MediaType } catch { }
                    if ($ct -and $ct -notmatch 'text/html|application/xhtml') { continue }
                    $html = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                    if (-not [string]::IsNullOrWhiteSpace($html)) { $responsePages.Add([PSCustomObject]@{ Provider=$entry.Provider; Html=$html; SearchPage=$entry.SearchPage; Query=$entry.Query }) }
                } catch {
                    Write-Log "Image search request failed for $($entry.Provider): $($_.Exception.Message)" 'DEBUG'
                } finally {
                    if ($resp) { $resp.Dispose() }
                }
            }
        }
    } catch {
        Write-Log "Image search setup failed: $($_.Exception.Message)" 'DEBUG'
    } finally {
        if ($client) { $client.Dispose() }
        elseif ($handler) { $handler.Dispose() }
    }

    $all = New-Object System.Collections.Generic.List[object]
    # Structured brand-logo search prevents the sparse game catalogue and brittle
    # search-page HTML from being the only way to find software logos.
    try {
        $iconifyCandidates = @(Get-IconifyBrandIconCandidates -Queries $iconifyQueries -MaxResults ([Math]::Min(14,$MaxResults)))
        foreach ($candidate in $iconifyCandidates) { $all.Add($candidate) }
        if ($iconifyCandidates.Count -gt 0) { Write-Log "Iconify returned $($iconifyCandidates.Count) semantically matched brand icon(s) for '$cleanQuery'." 'INFO' }
    } catch { Write-Log "Iconify candidates unavailable for '$cleanQuery': $($_.Exception.Message)" 'DEBUG' }
    foreach ($page in $responsePages) {
        try {
            $found = @(Get-ImageSearchCandidatesFromHtml -Html ([string]$page.Html) -Provider ([string]$page.Provider) -Query ([string]$page.Query) -MaxResults $MaxResults -SearchPage ([string]$page.SearchPage))
            foreach ($item in $found) { $all.Add($item) }
        } catch { Write-Log "Could not parse $($page.Provider) image results: $($_.Exception.Message)" 'DEBUG' }
    }
    $dedup = @{}
    foreach ($item in @($all | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression={if ($_.Width -gt 0 -and $_.Height -gt 0) {$_.Width * $_.Height} else {0}};Descending=$true})) {
        $key = [string]$item.Url
        if ([string]::IsNullOrWhiteSpace($key) -or $dedup.ContainsKey($key)) { continue }
        $dedup[$key] = $item
    }
    return @($dedup.Values | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression={if ($_.Width -gt 0 -and $_.Height -gt 0) {$_.Width * $_.Height} else {0}};Descending=$true} | Select-Object -First ([Math]::Max(1,$MaxResults)))
}
