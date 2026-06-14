# ============================================================
#  SteamGridDB.ps1 (v5) - API client, advanced matching engine
#  Game candidates with year-aware confidence scoring, Steam
#  AppID priority lookup, ambiguity detection, and artwork
#  candidates for GRID (square) / ICON / LOGO categories sorted
#  by community score then resolution.
# ============================================================

$script:SgdbBaseUrl = 'https://www.steamgriddb.com/api/v2'

function Invoke-SgdbApi {
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$Endpoint
    )

    $uri = "$script:SgdbBaseUrl$Endpoint"
    $headers = @{ Authorization = "Bearer $ApiKey" }

    try {
        return Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 30
    } catch {
        $statusCode = $null
        try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { }

        if ($statusCode -eq 401) {
            throw [System.UnauthorizedAccessException]::new('SteamGridDB rejected the API key (HTTP 401).')
        }
        if ($statusCode -eq 404) {
            return $null
        }
        if ($statusCode -eq 429) {
            Write-Log 'SteamGridDB rate limit hit (HTTP 429). Waiting 5 seconds...' 'WARN'
            Start-Sleep -Seconds 5
            try {
                return Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 30
            } catch {
                throw "SteamGridDB request failed after retry: $($_.Exception.Message)"
            }
        }
        throw "SteamGridDB request failed ($uri): $($_.Exception.Message)"
    }
}

function Test-SgdbConnection {
    param([Parameter(Mandatory)][string]$ApiKey)
    try {
        $null = Invoke-SgdbApi -ApiKey $ApiKey -Endpoint '/search/autocomplete/portal'
        return $true
    } catch [System.UnauthorizedAccessException] {
        throw
    } catch {
        return $false
    }
}

# ---------------- Fuzzy similarity ----------------

function Get-LevenshteinDistance {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$A,
        [Parameter(Mandatory)][AllowEmptyString()][string]$B
    )

    if ($A.Length -eq 0) { return $B.Length }
    if ($B.Length -eq 0) { return $A.Length }

    $prev = New-Object int[] ($B.Length + 1)
    $curr = New-Object int[] ($B.Length + 1)
    for ($j = 0; $j -le $B.Length; $j++) { $prev[$j] = $j }

    for ($i = 1; $i -le $A.Length; $i++) {
        $curr[0] = $i
        for ($j = 1; $j -le $B.Length; $j++) {
            $cost = if ($A[$i - 1] -eq $B[$j - 1]) { 0 } else { 1 }
            $curr[$j] = [Math]::Min(
                [Math]::Min($curr[$j - 1] + 1, $prev[$j] + 1),
                $prev[$j - 1] + $cost
            )
        }
        $tmp = $prev; $prev = $curr; $curr = $tmp
    }
    return $prev[$B.Length]
}

function Get-CompareKey {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Name)
    $k = $Name.ToLowerInvariant()
    $k = $k -replace '&', 'and'
    $k = $k -replace '[^a-z0-9]', ''
    return $k
}

function Get-NameSimilarity {
    param(
        [Parameter(Mandatory)][string]$A,
        [Parameter(Mandatory)][string]$B
    )

    $ka = Get-CompareKey $A
    $kb = Get-CompareKey $B

    if ($ka.Length -eq 0 -or $kb.Length -eq 0) { return 0.0 }
    if ($ka -eq $kb) { return 1.0 }

    $dist = Get-LevenshteinDistance -A $ka -B $kb
    $maxLen = [Math]::Max($ka.Length, $kb.Length)
    $score = 1.0 - ($dist / $maxLen)

    if ($ka.Contains($kb) -or $kb.Contains($ka)) {
        $score = [Math]::Max($score, 0.85)
    }
    return [Math]::Round($score, 3)
}

# ---------------- Game candidates + matching ----------------

function Get-SgdbGameCandidates {
    <#
        Searches SteamGridDB and returns scored game candidates:
        @{ GameId; Name; Year; Score } sorted by score descending.
        Year comes from the API release_date when available.
    #>
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$Query,
        [int]$Top = 8
    )

    $encoded = [uri]::EscapeDataString($Query)
    $response = Invoke-SgdbApi -ApiKey $ApiKey -Endpoint "/search/autocomplete/$encoded"

    if ($null -eq $response -or -not $response.success -or $null -eq $response.data) { return @() }

    $out = @()
    foreach ($item in @($response.data)) {
        $year = 0
        try {
            if ($item.PSObject.Properties.Name -contains 'release_date' -and $item.release_date -and [int64]$item.release_date -gt 0) {
                $year = ([System.DateTimeOffset]::FromUnixTimeSeconds([int64]$item.release_date)).Year
            }
        } catch { $year = 0 }

        $out += [PSCustomObject]@{
            GameId = [int]$item.id
            Name   = [string]$item.name
            Year   = [int]$year
            Score  = Get-NameSimilarity -A $Query -B ([string]$item.name)
        }
    }

    $sorted = @($out | Sort-Object -Property Score -Descending)
    # Plain return: items enumerate; caller collects with @(...)
    return @($sorted | Select-Object -First $Top)
}

function Get-SgdbGameBySteamAppId {
    <#
        Definitive lookup: maps a Steam AppID directly to the
        SteamGridDB game. Returns @{ GameId; Name } or $null.
    #>
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][int64]$AppId
    )
    try {
        $r = Invoke-SgdbApi -ApiKey $ApiKey -Endpoint "/games/steam/$AppId"
        if ($r -and $r.success -and $r.data -and $r.data.id) {
            return [PSCustomObject]@{ GameId = [int]$r.data.id; Name = [string]$r.data.name }
        }
    } catch [System.UnauthorizedAccessException] {
        throw
    } catch { }
    return $null
}

function Get-SgdbGameNameById {
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][int]$GameId
    )
    try {
        $r = Invoke-SgdbApi -ApiKey $ApiKey -Endpoint "/games/id/$GameId"
        if ($r -and $r.success -and $r.data -and $r.data.name) { return [string]$r.data.name }
    } catch [System.UnauthorizedAccessException] {
        throw
    } catch { }
    return "Game #$GameId"
}

function Resolve-GameMatch {
    <#
        Advanced matching with error prevention (plan rules 1 + 11):
        1. Steam AppID wins outright when present (definitive).
        2. Candidates are scored by name similarity, adjusted by
           release-year agreement (+0.08 match / -0.05 mismatch).
        3. The match is flagged Ambiguous (asks the user) only when:
           - top score below 0.80, OR
           - a 0.80+ runner-up is within 0.03 of the top, OR
           - the shortcut year conflicts with the top candidate, OR
           - 6+ candidates score 0.85+ (very crowded franchise)
        Returns @{ GameId; GameName; Score; Ambiguous; Candidates }.
        GameId = 0 means no confident match.
    #>
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$Name,
        [int]$Year = 0,
        [int64]$SteamAppId = 0,
        [double]$MinScore = 0.55,
        [int]$Top = 8
    )

    if ($SteamAppId -gt 0) {
        $steamGame = Get-SgdbGameBySteamAppId -ApiKey $ApiKey -AppId $SteamAppId
        if ($null -ne $steamGame) {
            return [PSCustomObject]@{
                GameId = $steamGame.GameId; GameName = $steamGame.Name
                Score = 1.0; Ambiguous = $false; Candidates = @()
            }
        }
    }

    $cands = @(Get-SgdbGameCandidates -ApiKey $ApiKey -Query $Name -Top $Top)

    if ($Year -gt 0) {
        foreach ($c in $cands) {
            if ($c.Year -gt 0) {
                if ($c.Year -eq $Year) { $c.Score = [Math]::Min(1.0, [Math]::Round($c.Score + 0.08, 3)) }
                else { $c.Score = [Math]::Max(0.0, [Math]::Round($c.Score - 0.05, 3)) }
            }
        }
        $cands = @($cands | Sort-Object -Property Score -Descending)
    }

    if ($cands.Count -eq 0 -or $cands[0].Score -lt $MinScore) {
        return [PSCustomObject]@{ GameId = 0; GameName = $null; Score = 0.0; Ambiguous = $true; Candidates = $cands }
    }

    # Confidence tuned to ask LESS: the score system ranks #1 correctly
    # almost always, so only flag genuinely close or conflicting calls.
    $top1 = $cands[0]
    $ambiguous = $false
    if ($top1.Score -lt 0.80) { $ambiguous = $true }
    if ($cands.Count -ge 2 -and (($top1.Score - $cands[1].Score) -lt 0.03) -and $cands[1].Score -ge 0.80) { $ambiguous = $true }
    if ($Year -gt 0 -and $top1.Year -gt 0 -and $top1.Year -ne $Year) { $ambiguous = $true }
    if (@($cands | Where-Object { $_.Score -ge 0.85 }).Count -ge 6) { $ambiguous = $true }

    return [PSCustomObject]@{
        GameId = $top1.GameId; GameName = $top1.Name
        Score = $top1.Score; Ambiguous = $ambiguous; Candidates = $cands
    }
}

# ---------------- Artwork candidates (GRID / ICON / LOGO) ----------------

function Get-SgdbArtworkCandidates {
    <#
        Returns the top N artwork candidates for a game and category:
        @{ Url; Thumb; Score; Width; Height } sorted by community
        score, then by resolution (largest first). Static PNG/JPEG
        only, so GDI+ can always decode them.
        Kinds: square (1:1 grids), grid (any grid), icon, logo.
    #>
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][int]$GameId,
        [ValidateSet('square','grid','icon','logo')][string]$Kind = 'square',
        [int]$Top = 10
    )

    $safeFilter = 'mimes=image/png,image/jpeg&types=static'
    $endpoint = switch ($Kind) {
        'square' { "/grids/game/$GameId`?dimensions=512x512,1024x1024&$safeFilter" }
        'grid'   { "/grids/game/$GameId`?$safeFilter" }
        'icon'   { "/icons/game/$GameId" }
        'logo'   { "/logos/game/$GameId`?types=static&mimes=image/png" }
    }

    $data = $null
    try {
        $r = Invoke-SgdbApi -ApiKey $ApiKey -Endpoint $endpoint
        if ($r -and $r.success -and $r.data -and @($r.data).Count -gt 0) { $data = $r.data }
    } catch [System.UnauthorizedAccessException] {
        throw
    } catch {
        Write-Log "Artwork lookup ($Kind) failed for game $GameId : $($_.Exception.Message)" 'WARN'
    }

    if ($null -eq $data) { return @() }

    $out = @()
    foreach ($p in @($data)) {
        $score = 0
        if ($p.PSObject.Properties.Name -contains 'score' -and $null -ne $p.score) { $score = [int]$p.score }
        $w = 0; $h = 0
        if ($p.PSObject.Properties.Name -contains 'width'  -and $null -ne $p.width)  { $w = [int]$p.width }
        if ($p.PSObject.Properties.Name -contains 'height' -and $null -ne $p.height) { $h = [int]$p.height }
        $thumb = if ($p.PSObject.Properties.Name -contains 'thumb' -and $p.thumb) { [string]$p.thumb } else { [string]$p.url }

        $out += [PSCustomObject]@{
            Url = [string]$p.url; Thumb = $thumb
            Score = $score; Width = $w; Height = $h
        }
    }

    # Universal quality rule: best community score first,
    # highest resolution breaks ties.
    $sorted = @($out | Sort-Object -Property @(
        @{ Expression = 'Score'; Descending = $true },
        @{ Expression = { $_.Width * $_.Height }; Descending = $true }
    ))

    # Plain return (v3 lesson: never 'return ,$x' here)
    return @($sorted | Select-Object -First $Top)
}

function Get-BestArtwork {
    <#
        Automatic best pick for a category, with safe fallbacks:
        square -> grid -> icon | icon -> square -> grid | logo -> square -> icon
        Returns @{ Url; Kind } or $null.
    #>
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][int]$GameId,
        [ValidateSet('square','icon','logo')][string]$Category = 'square'
    )

    $chain = switch ($Category) {
        'icon' { @('icon', 'square', 'grid') }
        'logo' { @('logo', 'square', 'icon') }
        default { @('square', 'grid', 'icon') }
    }

    foreach ($kind in $chain) {
        $cands = @(Get-SgdbArtworkCandidates -ApiKey $ApiKey -GameId $GameId -Kind $kind -Top 1)
        if ($cands.Count -gt 0) {
            return [PSCustomObject]@{ Url = $cands[0].Url; Kind = $kind }
        }
    }
    return $null
}

# ---------------- v5.5: multi-game cover candidates ----------------

function Get-GameMatchSections {
    <#
        For the visual browser matcher: returns the top candidate
        games for a query, EACH with its own best covers, so the
        user picks game + cover in one click.
        Returns an array of:
          @{ GameId; GameName; Year; Score; Covers = @( @{Url;Thumb;Score} ) }
        Games with zero covers in the chosen category are skipped.
    #>
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$Query,
        [string]$Category = 'square',
        [int]$MaxGames = 5,
        [int]$CoversPerGame = 10
    )

    $games = @(Get-SgdbGameCandidates -ApiKey $ApiKey -Query $Query -Top $MaxGames)
    $sections = @()

    foreach ($g in $games) {
        $covers = @(Get-SgdbArtworkCandidates -ApiKey $ApiKey -GameId $g.GameId -Kind $Category -Top $CoversPerGame)
        if ($covers.Count -eq 0) { continue }
        $sections += [PSCustomObject]@{
            GameId   = [int]$g.GameId
            GameName = [string]$g.Name
            Year     = [int]$g.Year
            Score    = [double]$g.Score
            Covers   = $covers
        }
    }
    return @($sections)
}

# ---------------- v6.3: fast single-match for live scanning ----------------

function Get-GameMatchFast {
    <#
        FAST path for browser scanning: resolves the single best game
        and fetches ONLY that game's covers. This is one search call
        plus one artwork call per shortcut (versus fetching covers for
        every candidate). Alternatives are loaded later, on demand,
        via Get-GameAlternatives only if the user says "wrong game".

        Returns @{ best = @{gameId;gameName;year;covers}; confident;
                   candidateGames = @(@{gameId;gameName;year;score}) }
        candidateGames carries the lightweight runner-up list (names +
        scores only, NO covers) so the "wrong game" screen can show
        instantly and fetch covers per game on click.
    #>
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$Query,
        [string]$Category = 'square',
        [int]$Year = 0,
        [int64]$SteamAppId = 0,
        [int]$CoversPerGame = 10
    )

    $match = Resolve-GameMatch -ApiKey $ApiKey -Name $Query -Year $Year -SteamAppId $SteamAppId
    if ($match.GameId -le 0) {
        return [PSCustomObject]@{ best = $null; confident = $false; candidateGames = @() }
    }

    $covers = @(Get-SgdbArtworkCandidates -ApiKey $ApiKey -GameId $match.GameId -Kind $Category -Top $CoversPerGame)

    # Lightweight candidate list (no covers) for the "wrong game" screen.
    $candList = @()
    foreach ($c in @($match.Candidates)) {
        $candList += [PSCustomObject]@{
            GameId = [int]$c.GameId; GameName = [string]$c.Name
            Year = [int]$c.Year; Score = [double]$c.Score
        }
    }
    if ($candList.Count -eq 0) {
        $candList += [PSCustomObject]@{ GameId = [int]$match.GameId; GameName = [string]$match.GameName; Year = 0; Score = [double]$match.Score }
    }

    $best = [PSCustomObject]@{
        GameId   = [int]$match.GameId
        GameName = [string]$match.GameName
        Year     = 0
        Covers   = $covers
    }
    # try to attach the year of the matched game from the candidate list
    foreach ($c in $candList) { if ($c.GameId -eq $match.GameId) { $best.Year = [int]$c.Year; break } }

    return [PSCustomObject]@{
        best           = $best
        confident      = (-not $match.Ambiguous)
        candidateGames = $candList
    }
}

function Get-GameCovers {
    <#
        Fetches just one game's covers (used when the user picks a
        different game on the "wrong game" screen). Returns an array
        of @{Url;Thumb;Score}.
    #>
    param(
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][int]$GameId,
        [string]$Category = 'square',
        [int]$CoversPerGame = 10
    )
    return @(Get-SgdbArtworkCandidates -ApiKey $ApiKey -GameId $GameId -Kind $Category -Top $CoversPerGame)
}
