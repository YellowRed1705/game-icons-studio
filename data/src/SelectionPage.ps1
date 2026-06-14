# ============================================================
#  SelectionPage.ps1 (v5.5) - Interactive browser pages
#  Two page types, both single dark-themed local HTML files,
#  no server, no GUI framework:
#    1. New-SelectionPage      : pick a cover per game (covers only)
#    2. New-GameMatchPage      : pick game + cover in ONE click
#       (each candidate game is a section showing its best covers)
# ============================================================

function Get-SelectionPageHead {
    @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>SteamGridDB Icon Updater</title>
<style>
  body { background:#0f1115; color:#e6e6e6; font-family:'Segoe UI',sans-serif; margin:0; padding:24px; }
  h1 { font-size:20px; color:#4da3ff; margin:0 0 4px 0; }
  p.hint { color:#9aa3ad; margin:0 0 20px 0; font-size:14px; }
  .toolbar { position:sticky; top:0; background:#0f1115ee; padding:12px 0; border-bottom:1px solid #232733; margin-bottom:20px; z-index:5; }
  #code { width:360px; background:#1a1e27; color:#7ee787; border:1px solid #2c3140; border-radius:6px; padding:8px 10px; font-family:Consolas,monospace; font-size:14px; }
  button { background:#2563eb; color:#fff; border:0; border-radius:6px; padding:9px 16px; font-size:14px; cursor:pointer; margin-left:8px; }
  button:hover { background:#1d4ed8; }
  .shortcut { margin-bottom:34px; padding-bottom:20px; border-bottom:2px solid #232733; }
  .shortcut > h2 { font-size:17px; margin:0 0 14px 0; color:#ffd166; }
  .shortcut > h2 .num { color:#4da3ff; margin-right:6px; }
  .game { margin:0 0 16px 0; padding:10px 12px; background:#141821; border-radius:10px; }
  .game h3 { font-size:14px; margin:0 0 8px 0; color:#dbe2ea; font-weight:600; }
  .game h3 .yr { color:#9aa3ad; font-weight:400; margin-left:6px; }
  .opts { display:flex; flex-wrap:wrap; gap:10px; }
  .opt { cursor:pointer; text-align:center; border:3px solid transparent; border-radius:12px; padding:4px; transition:border-color .12s; }
  .opt img { width:120px; height:120px; object-fit:cover; border-radius:8px; display:block; background:#1a1e27; }
  .opt span { display:block; font-size:11px; color:#9aa3ad; margin-top:4px; }
  .opt.sel { border-color:#4da3ff; }
  .opt.sel span { color:#4da3ff; font-weight:600; }
  .done { color:#7ee787; }
</style>
</head>
<body>
'@
}

# ---------------- Page 1: covers per game ----------------

function New-SelectionPage {
    <#
        $Pending: list of @{ Index; Name; GameName; Candidates }.
        One row per game; click a cover. Code: "i:c;i:c".
        Writes Cache\Selection.html and returns its path.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Pending
    )

    $sb = New-Object System.Text.StringBuilder
    $null = $sb.Append((Get-SelectionPageHead))
    $null = $sb.Append("<h1>Choose your covers</h1>`n")
    $null = $sb.Append('<p class="hint">Click one cover per game (top scored is preselected). Then press COPY CODE and paste the code into the PowerShell window.</p>' + "`n")
    $null = $sb.Append('<div class="toolbar"><input id="code" readonly value="OK"><button onclick="copyCode()">COPY CODE</button></div>' + "`n")

    foreach ($game in $Pending) {
        $safeName = [System.Net.WebUtility]::HtmlEncode([string]$game.Name)
        $null = $sb.Append("<div class=""shortcut"" data-i=""$($game.Index)"">`n")
        $null = $sb.Append("<h2><span class=""num"">$($game.Index).</span>$safeName</h2>`n<div class=""opts"">`n")
        $c = 0
        foreach ($cand in $game.Candidates) {
            $c++
            $thumb = [System.Net.WebUtility]::HtmlEncode([string]$cand.Thumb)
            $null = $sb.Append("<div class=""opt"" data-c=""$c""><img src=""$thumb"" loading=""lazy""><span>#$c - score $($cand.Score)</span></div>`n")
        }
        $null = $sb.Append("</div></div>`n")
    }

    $script = @'
<script>
var sel = {};
function update() {
  var parts = [];
  for (var k in sel) { if (sel[k] !== '1') parts.push(k + ':' + sel[k]); }
  document.getElementById('code').value = parts.length ? parts.join(';') : 'OK';
}
function copyCode() {
  var c = document.getElementById('code');
  c.select(); c.setSelectionRange(0, 9999);
  try { document.execCommand('copy'); } catch (e) {}
  if (navigator.clipboard) { try { navigator.clipboard.writeText(c.value); } catch (e) {} }
}
document.querySelectorAll('.shortcut').forEach(function (s) {
  s.querySelectorAll('.opt').forEach(function (o) {
    o.addEventListener('click', function () {
      s.querySelectorAll('.opt').forEach(function (x) { x.classList.remove('sel'); });
      o.classList.add('sel');
      sel[s.dataset.i] = o.dataset.c;
      update();
    });
  });
  var f = s.querySelector('.opt');
  if (f) { f.classList.add('sel'); sel[s.dataset.i] = '1'; }
});
update();
</script>
</body>
</html>
'@
    $null = $sb.Append($script)

    $cacheDir = Join-Path $Root 'Cache'
    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    $htmlPath = Join-Path $cacheDir 'Selection.html'
    Set-Content -Path $htmlPath -Value $sb.ToString() -Encoding UTF8
    return $htmlPath
}

# ---------------- Page 2: game + cover in one click ----------------

function New-GameMatchPage {
    <#
        Step-by-step wizard (one shortcut on screen at a time).
        $Pending: list of @{ Index; Name; Sections } where each
        Section = @{ GameId; GameName; Year; Score; Covers }.
        For the current shortcut the page shows each candidate game
        with that game's best covers. Clicking ONE cover records the
        game+cover choice and advances to the next shortcut.
        At the end the page shows the final code to copy.
        Code format: "i:gIdx:cIdx;..."
        Writes Cache\GameMatch.html and returns its path.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Pending
    )

    $sb = New-Object System.Text.StringBuilder
    $null = $sb.Append((Get-SelectionPageHead))
    $null = $sb.Append("<h1>Match game + pick cover</h1>`n")
    $null = $sb.Append('<p class="hint">One shortcut at a time. Click the cover that is the right game AND the look you want; the page moves to the next one automatically. At the end, press COPY CODE and paste it into PowerShell.</p>' + "`n")
    $null = $sb.Append('<div class="toolbar"><span id="progress" style="color:#4da3ff;font-weight:600;margin-right:12px;"></span><input id="code" readonly value="" style="display:none;"><button id="copybtn" onclick="copyCode()" style="display:none;">COPY CODE</button><button id="backbtn" onclick="goBack()" style="display:none;background:#374151;">BACK</button></div>' + "`n")

    foreach ($item in $Pending) {
        $safeName = [System.Net.WebUtility]::HtmlEncode([string]$item.Name)
        $null = $sb.Append("<div class=""shortcut"" data-i=""$($item.Index)"" style=""display:none;"">`n")
        $null = $sb.Append("<h2><span class=""num"">$($item.Index).</span>$safeName</h2>`n")

        $gi = 0
        foreach ($section in $item.Sections) {
            $gi++
            $gname = [System.Net.WebUtility]::HtmlEncode([string]$section.GameName)
            $yr = if ($section.Year -gt 0) { "<span class=""yr"">($($section.Year))</span>" } else { '' }
            $null = $sb.Append("<div class=""game"" data-g=""$gi""><h3>$gname$yr</h3>`n<div class=""opts"">`n")
            $ci = 0
            foreach ($cover in $section.Covers) {
                $ci++
                $thumb = [System.Net.WebUtility]::HtmlEncode([string]$cover.Thumb)
                $scoreLabel = if ([int]$cover.Score -gt 0) { "score $($cover.Score)" } else { "&nbsp;" }
                $null = $sb.Append("<div class=""opt"" data-g=""$gi"" data-c=""$ci""><img src=""$thumb"" loading=""lazy""><span>$scoreLabel</span></div>`n")
            }
            $null = $sb.Append("</div></div>`n")
        }
        # Skip option for this shortcut
        $null = $sb.Append('<div style="margin-top:6px;"><button class="skipbtn" style="background:#374151;">Skip this one (keep current icon)</button></div>' + "`n")
        $null = $sb.Append("</div>`n")
    }

    $script = @'
<script>
var cards = Array.prototype.slice.call(document.querySelectorAll('.shortcut'));
var sel = {};        // shortcutIndex -> "g:c"
var pos = 0;         // current card position
var visited = [];    // visited positions for BACK

function show(p) {
  cards.forEach(function (c, idx) { c.style.display = (idx === p ? 'block' : 'none'); });
  var prog = document.getElementById('progress');
  if (p < cards.length) {
    prog.textContent = 'Shortcut ' + (p + 1) + ' / ' + cards.length;
    document.getElementById('code').style.display = 'none';
    document.getElementById('copybtn').style.display = 'none';
  }
  document.getElementById('backbtn').style.display = (visited.length ? 'inline-block' : 'none');
  window.scrollTo(0, 0);
}

function buildCode() {
  var parts = [];
  for (var k in sel) { parts.push(k + ':' + sel[k]); }
  return parts.join(';');
}

function finish() {
  cards.forEach(function (c) { c.style.display = 'none'; });
  document.getElementById('progress').textContent = 'All done! Copy the code below:';
  var code = document.getElementById('code');
  code.value = buildCode() || 'OK';
  code.style.display = 'inline-block';
  document.getElementById('copybtn').style.display = 'inline-block';
  document.getElementById('backbtn').style.display = 'inline-block';
  copyCode();
}

function advance() {
  visited.push(pos);
  pos++;
  if (pos >= cards.length) { finish(); } else { show(pos); }
}

function goBack() {
  if (!visited.length) return;
  pos = visited.pop();
  show(pos);
}

function copyCode() {
  var c = document.getElementById('code');
  c.select(); c.setSelectionRange(0, 9999);
  try { document.execCommand('copy'); } catch (e) {}
  if (navigator.clipboard) { try { navigator.clipboard.writeText(c.value); } catch (e) {} }
}

cards.forEach(function (card) {
  var i = card.dataset.i;
  card.querySelectorAll('.opt').forEach(function (o) {
    o.addEventListener('click', function () {
      sel[i] = o.dataset.g + ':' + o.dataset.c;
      advance();
    });
  });
  var sk = card.querySelector('.skipbtn');
  if (sk) { sk.addEventListener('click', function () { delete sel[i]; advance(); }); }
});

if (cards.length) { show(0); } else { finish(); }
</script>
</body>
</html>
'@
    $null = $sb.Append($script)

    $cacheDir = Join-Path $Root 'Cache'
    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    $htmlPath = Join-Path $cacheDir 'GameMatch.html'
    Set-Content -Path $htmlPath -Value $sb.ToString() -Encoding UTF8
    return $htmlPath
}

# ---------------- Code parsers ----------------

function Read-SelectionChoices {
    <#
        Parses "2:3;7:1" -> hashtable (string gameIndex) -> coverNumber.
        Empty / "OK" means: top-scored cover for everything.
    #>
    param()

    $raw = Read-Host '  Paste selection code here (Enter or OK = top scored for all)'
    $map = @{}

    if ([string]::IsNullOrWhiteSpace($raw)) { return $map }
    $raw = $raw.Trim()
    if ($raw.ToUpperInvariant() -eq 'OK') { return $map }

    foreach ($pair in $raw.Split(';')) {
        $kv = $pair.Trim().Split(':')
        if ($kv.Count -eq 2) {
            $i = 0; $c = 0
            if ([int]::TryParse($kv[0].Trim(), [ref]$i) -and [int]::TryParse($kv[1].Trim(), [ref]$c)) {
                if ($i -gt 0 -and $c -gt 0) { $map[[string]$i] = $c }
            }
        }
    }
    return $map
}

function Read-GameMatchChoices {
    <#
        Parses "2:1:3;7:2:5" -> hashtable (string shortcutIndex) ->
        @{ Game = <int>; Cover = <int> }. Empty input returns empty
        (caller then falls back to the best game + best cover).
    #>
    param()

    $raw = Read-Host '  Paste your selection code here (Enter = best guess for all)'
    $map = @{}

    if ([string]::IsNullOrWhiteSpace($raw)) { return $map }
    $raw = $raw.Trim()
    if ($raw.ToUpperInvariant() -eq 'OK') { return $map }

    foreach ($triple in $raw.Split(';')) {
        $parts = $triple.Trim().Split(':')
        if ($parts.Count -eq 3) {
            $i = 0; $g = 0; $c = 0
            if ([int]::TryParse($parts[0].Trim(), [ref]$i) -and `
                [int]::TryParse($parts[1].Trim(), [ref]$g) -and `
                [int]::TryParse($parts[2].Trim(), [ref]$c)) {
                if ($i -gt 0 -and $g -gt 0 -and $c -gt 0) {
                    $map[[string]$i] = @{ Game = $g; Cover = $c }
                }
            }
        }
    }
    return $map
}
