# ============================================================
#  UiTools.ps1 - Console UX helpers
#  Single-keypress input (no Enter needed), inline ASCII
#  progress bars, phase banners, durations, report bar charts.
# ============================================================

function Read-KeyChoice {
    <#
        Waits for a SINGLE keypress (no Enter needed) from a set of
        allowed characters. Enter returns the default when provided.
        Falls back to Read-Host on hosts without raw key support.
    #>
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string[]]$Allowed,
        [string]$Default = ''
    )

    Write-Host -NoNewline "$Prompt " -ForegroundColor White

    while ($true) {
        $keyInfo = $null
        try {
            $keyInfo = [Console]::ReadKey($true)
        } catch {
            # Fallback: classic line input
            $typed = Read-Host
            $typed = if ($null -ne $typed) { $typed.Trim().ToLowerInvariant() } else { '' }
            if ($typed -eq '' -and $Default -ne '') { return $Default }
            if ($Allowed -contains $typed) { return $typed }
            Write-Host -NoNewline "$Prompt " -ForegroundColor White
            continue
        }

        if ($keyInfo.Key -eq [ConsoleKey]::Enter -and $Default -ne '') {
            Write-Host $Default -ForegroundColor Cyan
            return $Default
        }
        $ch = ([string]$keyInfo.KeyChar).ToLowerInvariant()
        if ($Allowed -contains $ch) {
            Write-Host $ch -ForegroundColor Cyan
            return $ch
        }
        # Ignore any other key silently and keep waiting
    }
}

function Read-YesNoKey {
    <#
        Single-key yes/no. Accepts y/n and Turkish e/h.
        Enter picks the default.
    #>
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [bool]$DefaultYes = $false
    )
    $suffix  = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    $default = if ($DefaultYes) { 'y' } else { 'n' }
    $answer = Read-KeyChoice -Prompt "$Prompt $suffix" -Allowed @('y','n','e','h') -Default $default
    return ($answer -in @('y','e'))
}

# ---------------- Inline progress bar ----------------

function Show-InlineProgress {
    param(
        [Parameter(Mandatory)][int]$Current,
        [Parameter(Mandatory)][int]$Total,
        [string]$Label = 'Working',
        [string]$Item = ''
    )
    if ($Total -le 0) { return }
    if ($Current -gt $Total) { $Current = $Total }

    $width  = 24
    $ratio  = $Current / [double]$Total
    $filled = [int][Math]::Floor($ratio * $width)
    $bar    = ('#' * $filled).PadRight($width, '.')
    $pct    = [int][Math]::Floor($ratio * 100)

    if ($Item.Length -gt 34) { $Item = $Item.Substring(0, 31) + '...' }

    $line = "`r  {0,-12} [{1}] {2,3}%  {3}/{4}  {5}" -f $Label, $bar, $pct, $Current, $Total, $Item
    $max = 110
    try { $max = [Math]::Max(70, [Console]::WindowWidth - 2) } catch { }
    if ($line.Length -gt $max) { $line = $line.Substring(0, $max) }
    Write-Host $line.PadRight($max) -NoNewline -ForegroundColor Cyan
}

function Complete-InlineProgress {
    Write-Host ''
}

# ---------------- Phase banners + durations ----------------

function Show-PhaseBanner {
    param([Parameter(Mandatory)][string]$Title)
    $pad = [Math]::Max(3, 54 - $Title.Length)
    Write-Host ''
    Write-Host ("  --- {0} {1}" -f $Title, ('-' * $pad)) -ForegroundColor DarkCyan
}

function Format-Duration {
    param([Parameter(Mandatory)][TimeSpan]$Span)
    if ($Span.TotalSeconds -lt 60) { return ('{0:n1}s' -f $Span.TotalSeconds) }
    return ('{0}m {1}s' -f [int][Math]::Floor($Span.TotalMinutes), $Span.Seconds)
}

# ---------------- Report bar chart ----------------

function Show-CountBar {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][int]$Value,
        [Parameter(Mandatory)][int]$Max,
        [System.ConsoleColor]$Color = [System.ConsoleColor]::Gray
    )
    $width = 28
    $len = 0
    if ($Max -gt 0 -and $Value -gt 0) {
        $len = [Math]::Max(1, [int][Math]::Round(($Value / [double]$Max) * $width))
    }
    $bar = ('#' * $len).PadRight($width)
    Write-Host ("   {0,-14}[{1}] {2}" -f $Label, $bar, $Value) -ForegroundColor $Color
}

# ---------------- v5 additions: lists + range input ----------------

function Show-NumberedList {
    param(
        [Parameter(Mandatory)]$Items,
        [string]$Title = ''
    )
    if ($Title -ne '') {
        Write-Host ''
        Write-Host "  $Title" -ForegroundColor Cyan
    }
    $i = 0
    foreach ($item in @($Items)) {
        $i++
        Write-Host ("   [{0,3}] {1}" -f $i, $item)
    }
}

function ConvertFrom-RangeInput {
    <#
        Parses selections like "2,4", "2-5", "1,3-6,9" or "all"
        into a sorted unique list of integers within 1..Max.
        Empty input returns an empty list (= cancel).
    #>
    param(
        [AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][int]$Max
    )

    $result = New-Object System.Collections.Generic.List[int]
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    $t = $Text.Trim().ToLowerInvariant()
    if ($t -in @('all', 'hepsi', '*')) { return @(1..$Max) }

    foreach ($token in $t.Split(',')) {
        $part = $token.Trim()
        if ($part -eq '') { continue }
        if ($part -match '^(\d+)\s*-\s*(\d+)$') {
            $a = [int]$matches[1]; $b = [int]$matches[2]
            if ($a -gt $b) { $tmp = $a; $a = $b; $b = $tmp }
            for ($n = $a; $n -le $b; $n++) {
                if ($n -ge 1 -and $n -le $Max -and -not $result.Contains($n)) { $result.Add($n) }
            }
        } elseif ($part -match '^\d+$') {
            $n = [int]$part
            if ($n -ge 1 -and $n -le $Max -and -not $result.Contains($n)) { $result.Add($n) }
        }
    }
    $sorted = @($result | Sort-Object)
    return $sorted
}
