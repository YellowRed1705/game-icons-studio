# ============================================================
#  WebApp.ps1 (v6.2) - Game Icons Studio browser UI
#  Single-page app served by WebServer.ps1. Browser-first:
#  home with 3 big actions -> guided wizard -> live apply.
#  Pure presentation; all real work is in the core modules.
# ============================================================

function Invoke-BrowserMode {
    <#
        Entry point for the browser-first experience (default mode).
        Builds a folder-less run context, then hands control to the
        local web server. Everything happens in the browser.
    #>
    param([Parameter(Mandatory)][string]$Root)

    $ctx = Get-RunContext -Root $Root -AskCategory $false -SkipFolderPrompt $true -SkipKeyPrompt $true
    if ($null -eq $ctx) { return }

    $ok = Start-IconWebApp -Root $Root -Ctx $ctx
    if (-not $ok) {
        Write-Host ''
        Write-Host '  Browser mode could not start on this machine.' -ForegroundColor Yellow
    }
}

function Get-WebAppHtml {
    $html = @'
<!DOCTYPE html>
<html lang="en" data-theme="glass">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Game Icons Studio</title>
<link rel="icon" type="image/png" href="/assets/brand.png">
<style>
  :root {
    --bg:#0b0d12; --panel:#141821; --panel2:#1a1e27; --line:#232733;
    --text:#e6e9ef; --muted:#9aa3ad; --accent:#3b82f6; --accent2:#60a5fa;
    --good:#34d399; --warn:#fbbf24; --bad:#f87171; --radius:18px; --fs:16px;
  }
  [data-theme="light"] {
    --bg:#f4f6fb; --panel:#ffffff; --panel2:#eef1f7; --line:#dfe4ee;
    --text:#1a2230; --muted:#5b6675; --accent:#2563eb; --accent2:#1d4ed8;
  }
  [data-theme="gaming"] {
    --bg:#0a0612; --panel:#150d24; --panel2:#1e1233; --line:#34215a;
    --text:#f0e9ff; --muted:#a99bcb; --accent:#a855f7; --accent2:#22d3ee;
    --good:#22d3ee; --warn:#fbbf24; --bad:#fb7185;
  }
  [data-theme="modern-dark"] {
    --bg:#101418; --panel:#171c22; --panel2:#1f262e; --line:#2a323c;
    --text:#eef2f6; --muted:#9bb0c0; --accent:#14b8a6; --accent2:#2dd4bf;
    --good:#34d399; --warn:#fbbf24; --bad:#f87171; --radius:22px;
  }
  [data-theme="modern-dark"] .card { box-shadow:0 20px 50px rgba(0,0,0,.45); }
  [data-theme="modern-light"] {
    --bg:#fbfaf7; --panel:#ffffff; --panel2:#f3f1ec; --line:#e7e3da;
    --text:#2b2a28; --muted:#7c776e; --accent:#e07a5f; --accent2:#c75c42;
    --good:#3d9970; --warn:#d99a06; --bad:#d1495b; --radius:22px;
  }
  [data-theme="modern-light"] .card { box-shadow:0 18px 44px rgba(120,110,90,.16); }
  [data-theme="minimal"] {
    --bg:#ffffff; --panel:#ffffff; --panel2:#f4f4f5; --line:#e4e4e7;
    --text:#18181b; --muted:#71717a; --accent:#18181b; --accent2:#3f3f46;
    --good:#16a34a; --warn:#ca8a04; --bad:#dc2626; --radius:10px;
  }
  [data-theme="glass"] {
    --bg:#0d1424; --panel:rgba(255,255,255,.07); --panel2:rgba(255,255,255,.10);
    --line:rgba(255,255,255,.18); --text:#eef3ff; --muted:#b6c2da;
    --accent:#38bdf8; --accent2:#7dd3fc;
  }
  [data-theme="glass"] body {
    background:radial-gradient(1200px 800px at 20% 10%, #1e3a5f 0%, transparent 55%),
               radial-gradient(900px 700px at 90% 90%, #3b2a5f 0%, transparent 50%), #0d1424;
  }
  [data-theme="glass"] .card, [data-theme="glass"] header { backdrop-filter:blur(14px); -webkit-backdrop-filter:blur(14px); }
  * { box-sizing:border-box; }
  html,body { height:100%; margin:0; }
  html { font-size:var(--fs); }
  body {
    background:var(--bg); color:var(--text);
    font-family:'Segoe UI',system-ui,-apple-system,sans-serif;
    display:flex; flex-direction:column; height:100vh; overflow:hidden;
  }
  header {
    display:flex; align-items:center; gap:10px; flex-wrap:wrap;
    padding:12px 18px; border-bottom:1px solid var(--line); background:var(--panel);
  }
  @media (max-width:780px){
    .brand p { display:none; }
    .iconbtn, .ghost, .theme-btn { padding:7px 10px; font-size:.8rem; }
  }
  .logo-img { width:42px; height:42px; object-fit:contain; flex:0 0 auto; }
  .logo { width:40px; height:40px; border-radius:11px;
    background:linear-gradient(160deg,var(--accent),#0b0d12); flex:0 0 auto;
    display:flex; align-items:flex-end; gap:3px; padding:8px; }
  .logo i { display:block; width:6px; border-radius:2px; background:var(--accent2); }
  .logo i:nth-child(1){ height:40%; } .logo i:nth-child(2){ height:65%; background:#7dd3fc;} .logo i:nth-child(3){ height:90%; background:var(--warn);}
  .brand h1 { font-size:1.15rem; margin:0; letter-spacing:.3px; }
  .brand p { font-size:.78rem; margin:1px 0 0 0; color:var(--muted); }
  .spacer { flex:1; }
  .iconbtn, .ghost, .theme-btn {
    background:var(--panel2); color:var(--text); border:1px solid var(--line);
    border-radius:10px; padding:8px 13px; font-size:.85rem; cursor:pointer;
  }
  .iconbtn:hover, .ghost:hover, .theme-btn:hover { border-color:var(--accent); }
  .view-toggle { display:flex; gap:8px; justify-content:center; margin-bottom:4px; }
  .vt-btn { padding:6px 14px; font-size:.85rem; }
  .vt-btn.active { background:var(--accent); color:#fff; border-color:var(--accent); }
  #artworkGrid.gallery { grid-template-columns:repeat(auto-fill,minmax(220px,1fr)); gap:18px; max-height:none; }
  #artworkGrid.gallery .tile img { border-radius:12px; }
  #artworkGrid.gallery .tile { padding:8px; }
  .zoombtn { font-size:1.15rem; font-weight:700; line-height:1; width:38px; height:34px;
    display:inline-flex; align-items:center; justify-content:center; padding:0; }
  .iconbtn:focus-visible, .ghost:focus-visible, .big-btn:focus-visible, .home-btn:focus-visible, .tile:focus-visible {
    outline:3px solid var(--accent2); outline-offset:2px;
  }

  .progress-wrap { padding:10px 24px 0; }
  .progress-wrap.hidden { display:none; }
  .steps { display:flex; gap:6px; }
  .step { flex:1; height:6px; border-radius:99px; background:var(--panel2); overflow:hidden; transition:background .3s; }
  .step.done { background:var(--good); }
  .step.active { background:var(--accent); }
  .step-labels { display:flex; gap:6px; margin-top:6px; }
  .step-labels span { flex:1; font-size:.72rem; color:var(--muted); text-align:center; }
  .step-labels span.active { color:var(--accent2); font-weight:600; }

  main { flex:1; overflow:auto; display:flex; align-items:center; justify-content:center; padding:18px; }
  .card {
    background:var(--panel); border:1px solid var(--line); border-radius:var(--radius);
    width:100%; max-width:1080px; max-height:calc(100vh - 150px); padding:28px;
    display:flex; flex-direction:column; gap:16px; overflow-y:auto; overflow-x:hidden;
    animation:cardIn .12s ease;
  }
  @media (max-width:780px){ .card { padding:20px; gap:12px; } .card h2 { font-size:1.25rem; } }
  @keyframes cardIn { from { opacity:0; transform:translateY(8px);} to {opacity:1; transform:none;} }
  .card h2 { margin:0; font-size:1.5rem; }
  .card .sub { color:var(--muted); font-size:.92rem; margin-top:-8px; }
  .center-col { display:flex; flex-direction:column; align-items:center; gap:18px; text-align:center; }

  .big-btn { background:var(--accent); color:#fff; border:0; border-radius:12px;
    padding:14px 26px; font-size:1rem; font-weight:600; cursor:pointer; }
  .big-btn:hover { background:var(--accent2); }
  .big-btn:disabled { opacity:.5; cursor:not-allowed; }
  /* Modern gradient action buttons with hover glow */
  .big-btn, .ghost { transition:transform .12s ease, box-shadow .2s ease, filter .2s ease, background .2s ease; }
  .big-btn:hover { transform:translateY(-1px); }
  .btn-good { background:linear-gradient(135deg,#22c55e,#16a34a); color:#fff; }
  .btn-good:hover { box-shadow:0 0 0 1px rgba(34,197,94,.5), 0 8px 26px rgba(34,197,94,.45); filter:brightness(1.06); }
  .btn-warn { background:linear-gradient(135deg,#fbbf24,#f59e0b); color:#3a2a05; }
  .btn-warn:hover { box-shadow:0 0 0 1px rgba(245,158,11,.5), 0 8px 26px rgba(245,158,11,.45); filter:brightness(1.05); }
  .btn-bad { background:linear-gradient(135deg,#f87171,#ef4444); color:#fff; }
  .btn-bad:hover { box-shadow:0 0 0 1px rgba(239,68,68,.5), 0 8px 26px rgba(239,68,68,.45); filter:brightness(1.06); }
  .btn-go { background:linear-gradient(135deg,#3b82f6,#2563eb); color:#fff; }
  .btn-go:hover { box-shadow:0 0 0 1px rgba(59,130,246,.5), 0 8px 26px rgba(59,130,246,.45); filter:brightness(1.06); }
  /* Ghost buttons get a soft glow on hover too */
  .ghost:hover { box-shadow:0 0 0 1px var(--accent), 0 6px 18px rgba(0,0,0,.25); transform:translateY(-1px); }
  /* Colored ghost variants (for secondary colored actions) */
  .ghost.g-warn { border-color:#f59e0b; color:#f59e0b; }
  .ghost.g-warn:hover { background:linear-gradient(135deg,#fbbf24,#f59e0b); color:#3a2a05; box-shadow:0 0 0 1px rgba(245,158,11,.5), 0 8px 22px rgba(245,158,11,.4); }
  .ghost.g-bad { border-color:#ef4444; color:#ef4444; }
  .ghost.g-bad:hover { background:linear-gradient(135deg,#f87171,#ef4444); color:#fff; box-shadow:0 0 0 1px rgba(239,68,68,.5), 0 8px 22px rgba(239,68,68,.4); }

  /* Key screen header image + tutorial */
  .key-logo { width:96px; height:96px; object-fit:contain; }
  .key-cols { display:flex; gap:18px; width:100%; max-width:820px; flex-wrap:wrap; justify-content:center; }
  .key-col { flex:1 1 340px; display:flex; flex-direction:column; gap:12px; align-items:stretch; }
  .key-col-title { font-weight:700; font-size:1.02rem; text-align:center; }
  .key-col .big-btn { width:100%; }
  .tutorial { display:flex; flex-direction:column; gap:10px; text-align:left;
    background:var(--panel2); border:1px solid var(--line); border-radius:14px;
    padding:16px 20px; width:100%; flex:1; }
  .tut-step { display:flex; align-items:flex-start; gap:12px; font-size:.92rem; color:var(--text); }
  .about-wrap { display:grid; grid-template-columns:repeat(auto-fit,minmax(280px,1fr)); gap:14px;
    width:100%; max-width:860px; margin:8px auto 4px; text-align:left; }
  .about-card { background:var(--panel2); border:1px solid var(--line); border-radius:12px; padding:14px 16px; }
  .about-h { font-weight:700; margin-bottom:6px; color:var(--text); }
  .about-card p { color:var(--muted); font-size:.9rem; line-height:1.5; margin:0; }
  .about-card b { color:var(--text); font-weight:600; }
  .home-tools { display:flex; gap:10px; flex-wrap:wrap; justify-content:center; margin-top:4px; }
  .tool-btn { font-size:.85rem; padding:7px 14px; }
  .history-list { width:100%; max-width:680px; display:flex; flex-direction:column; gap:8px; max-height:none; }
  .history-row { display:flex; align-items:center; gap:12px; background:var(--panel2);
    border:1px solid var(--line); border-radius:10px; padding:8px 12px; text-align:left;
    content-visibility:auto; contain-intrinsic-size:56px; }
  .hist-thumb { width:42px; height:42px; border-radius:7px; object-fit:cover; flex:0 0 auto; background:var(--panel); }
  .hist-ph { background:linear-gradient(135deg,#2b3550,#141821); }
  .hist-info { flex:1; min-width:0; }
  .hist-name { font-weight:600; font-size:.9rem; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .hist-sub { color:var(--muted); font-size:.78rem; }
  .ghost.g-good { border-color:#22c55e; color:#22c55e; }
  .ghost.g-good:hover { background:linear-gradient(135deg,#22c55e,#16a34a); color:#fff; box-shadow:0 0 0 1px rgba(34,197,94,.5), 0 8px 22px rgba(34,197,94,.4); }
  .health-row { display:flex; gap:14px; flex-wrap:wrap; justify-content:center; }
  .health-card { background:var(--panel2); border:1px solid var(--line); border-radius:12px; padding:14px 22px; text-align:center; min-width:120px; }
  .health-n { font-size:1.6rem; font-weight:700; }
  .health-l { font-size:.76rem; color:var(--muted); margin-top:2px; }
  .success-mark { width:64px; height:64px; border-radius:50%;
    background:linear-gradient(135deg,#22c55e,#16a34a); color:#fff; font-size:2rem;
    display:flex; align-items:center; justify-content:center; box-shadow:0 8px 24px rgba(34,197,94,.4); }
  .stats-box { width:100%; max-width:680px; margin-top:4px; }
  .stats-title { font-size:.82rem; color:var(--muted); text-align:center; margin-bottom:8px; text-transform:uppercase; letter-spacing:.06em; }
  .stats-row { display:flex; gap:12px; flex-wrap:wrap; justify-content:center; }
  .ministat { background:var(--panel2); border:1px solid var(--line); border-radius:12px;
    padding:12px 18px; text-align:center; min-width:120px; }
  .ministat-n { font-size:1.5rem; font-weight:700; color:var(--accent2); }
  .ministat-l { font-size:.74rem; color:var(--muted); margin-top:2px; }
  .tut-num { flex:0 0 auto; width:24px; height:24px; border-radius:50%;
    background:var(--accent); color:#fff; font-size:.8rem; font-weight:700;
    display:flex; align-items:center; justify-content:center; margin-top:1px; }
  .btn-row { display:flex; gap:10px; flex-wrap:wrap; justify-content:center; }

  /* HOME */
  .home-hero { text-align:center; }
  .home-hero h2 { font-size:1.9rem; margin-bottom:6px; }
  .home-hero p { color:var(--muted); margin:0; }
  .home-grid { display:flex; gap:18px; flex-wrap:wrap; justify-content:center; margin-top:8px; }
  .home-btn { width:230px; min-height:190px; background:var(--panel2); border:1px solid var(--line);
    border-radius:16px; padding:24px; cursor:pointer; display:flex; flex-direction:column;
    align-items:center; gap:12px; text-align:center; transition:transform .12s, border-color .12s; color:var(--text); }
  .home-btn:hover { transform:translateY(-3px); border-color:var(--accent); }
  .home-btn.focus { border-color:var(--accent2); transform:translateY(-3px); }
  .home-btn .ic { width:60px; height:60px; }
  .home-btn .t { font-size:1.05rem; font-weight:700; }
  .home-btn .d { font-size:.82rem; color:var(--muted); line-height:1.35; }

  .match-row { display:flex; gap:28px; align-items:center; justify-content:center; flex-wrap:wrap; }
  .cover-main { width:min(260px,40vw); height:min(260px,40vw); border-radius:16px; object-fit:cover;
    background:var(--panel2); border:3px solid var(--accent); }
  .match-info { text-align:left; max-width:360px; }
  .match-info .game-name { font-size:1.35rem; font-weight:700; }
  .match-info .game-year { color:var(--muted); font-size:.92rem; margin-top:2px; }
  .match-info .hint { color:var(--muted); font-size:.85rem; margin-top:14px; }

  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(130px,1fr));
    gap:14px; overflow-y:auto; padding:4px; max-height:50vh; }
  .tile { cursor:pointer; border:3px solid transparent; border-radius:12px; padding:4px;
    transition:border-color .12s, transform .12s; }
  .tile:hover { transform:translateY(-2px); }
  .tile img { width:100%; aspect-ratio:1; object-fit:cover; border-radius:8px; background:var(--panel2); display:block; }
  .tile.sel { border-color:var(--accent); }
  .tile.focus { border-color:var(--accent2); }

  /* Review grid: fills the card, scrolls with the page (no inner frame) */
  #reviewGrid { max-height:none; overflow:visible; grid-template-columns:repeat(auto-fill,minmax(110px,1fr)); }
  #reviewGrid .rev-tile img,
  #reviewGrid .rev-tile > div:first-child { transition:opacity .15s ease, filter .15s ease; }
  #reviewGrid .rev-tile:hover { transform:translateY(-2px); }
  #reviewGrid .rev-tile:hover img { opacity:.65; }
  #reviewGrid .rev-tile.picked img,
  #reviewGrid .rev-tile.picked > div:first-child { opacity:.35; filter:grayscale(.3); }
  #reviewGrid .rev-tile.picked { border-color:var(--accent); }
  #reviewGrid .rev-tile.picked::after {
    content:'\2713 selected'; position:absolute; top:8px; left:8px; z-index:3;
    background:var(--accent); color:#fff; font-size:.7rem; font-weight:600;
    padding:2px 8px; border-radius:99px; }
  .review-list { overflow-y:auto; max-height:54vh; display:flex; flex-direction:column; gap:10px; }
  .review-item { display:flex; align-items:center; gap:14px; background:var(--panel2);
    border:1px solid var(--line); border-radius:12px; padding:10px 14px; }
  .review-item img { width:54px; height:54px; border-radius:8px; object-fit:cover; background:var(--panel); }
  .review-item .ri-name { flex:1; }
  .review-item .ri-game { color:var(--muted); font-size:.82rem; }

  .report-grid { display:flex; gap:18px; flex-wrap:wrap; justify-content:center; }
  .stat { background:var(--panel2); border:1px solid var(--line); border-radius:12px;
    padding:18px 24px; text-align:center; min-width:120px; }
  .stat .n { font-size:1.9rem; font-weight:700; }
  .stat .l { color:var(--muted); font-size:.82rem; margin-top:4px; }
  #reviewGrid .rev-tile, #detailGrid .rev-tile {
    content-visibility:auto; contain-intrinsic-size:160px;
  }
  .rev-tile { position:relative; }
  .tile.nochg { cursor:default; }
  .tile.nochg:hover { transform:none; }

  .loading { display:flex; flex-direction:column; align-items:center; gap:16px; color:var(--muted); width:100%; }
  .spinner { width:46px; height:46px; border:4px solid var(--line); border-top-color:var(--accent);
    border-radius:50%; animation:spin 1s linear infinite; }
  @keyframes spin { to { transform:rotate(360deg); } }
  .bigbar { width:min(620px,76vw); height:14px; border-radius:99px; background:var(--panel2);
    border:1px solid var(--line); overflow:hidden; }
  .bigbar-fill { height:100%; width:0%; border-radius:99px;
    background:linear-gradient(90deg,var(--accent),var(--accent2)); transition:width .3s ease; }
  .phase-text { min-height:1.4em; font-size:1.02rem; color:var(--text); }
  .typed-caret::after { content:'|'; margin-left:1px; opacity:.7; animation:blink 1s step-end infinite; }
  @keyframes blink { 50% { opacity:0; } }

  .feed { width:min(620px,76vw); max-height:120px; overflow:hidden; display:flex; flex-direction:column; gap:4px; }
  .feed div { font-size:.85rem; color:var(--muted); animation:feedIn .3s ease; }
  .feed div b { color:var(--good); }
  @keyframes feedIn { from { opacity:0; transform:translateY(4px);} to {opacity:1; transform:none;} }

  .noart-preview { width:200px; height:200px; border-radius:16px; border:3px solid var(--line);
    display:flex; align-items:center; justify-content:center; text-align:center; padding:16px;
    color:#fff; font-weight:700; font-size:1.05rem; line-height:1.25;
    background:linear-gradient(135deg,#2b3550,#141821); word-break:break-word; }
  .auto-banner { background:linear-gradient(90deg,rgba(59,130,246,.18),transparent);
    border:1px solid var(--accent); border-radius:12px; padding:10px 16px; font-size:.9rem; color:var(--accent2); }
  .auto-btn { border-color:var(--accent); color:var(--accent2); font-weight:600; }
  .auto-btn:hover { background:var(--accent); color:#fff; }

  .footer-nav { display:flex; align-items:center; gap:12px; justify-content:center; }
  .kbd-hint { text-align:center; color:var(--muted); font-size:.76rem; }
  .kbd-hint b { color:var(--text); background:var(--panel2); border:1px solid var(--line);
    border-radius:5px; padding:1px 6px; font-weight:600; }
  .back-btn { background:var(--panel2); border:1px solid var(--line); color:var(--text);
    border-radius:10px; padding:8px 16px; cursor:pointer; font-size:.88rem; }
  .back-btn:hover { border-color:var(--accent); }
  .input-path { width:min(520px,70vw); background:var(--panel2); color:var(--text);
    border:1px solid var(--line); border-radius:10px; padding:11px 14px; font-size:.9rem; }
  .hidden { display:none !important; }
</style>
</head>
<body>
<header>
  <img class="logo-img" src="/assets/brand.png" alt="Game Icons Studio">
  <div class="brand">
    <h1>Game Icons Studio</h1>
    <p>From generic icons to a game shelf.</p>
  </div>
  <div class="spacer"></div>
  <button class="iconbtn" id="homeBtn" onclick="goHome()" title="Home">&#8962; Home</button>
  <button class="iconbtn" id="aboutBtn" onclick="showAbout()" title="What is GIS?">&#10067; What is GIS</button>
  <button class="iconbtn" id="summaryBtn" onclick="returnToSummary()" title="Back to your results summary" style="display:none;">&#8617; Summary</button>
  <button class="iconbtn zoombtn" onclick="zoomOut()" title="Smaller (-)">&minus;</button>
  <button class="iconbtn zoombtn" onclick="zoomIn()" title="Bigger (+)">+</button>
  <button class="iconbtn" id="fsBtn" onclick="toggleFullscreen()" title="Fullscreen (F)">&#9974; Fullscreen</button>
  <button class="theme-btn" id="themeBtn" onclick="cycleTheme()"><span id="themeIcon">&#9789;</span> <span id="themeTxt">Dark</span></button>
  <button class="ghost" onclick="quitApp()">Quit</button>
</header>

<div class="progress-wrap hidden" id="progressWrap">
  <div class="steps">
    <div class="step" data-s="0"></div><div class="step" data-s="1"></div>
    <div class="step" data-s="2"></div><div class="step" data-s="3"></div>
  </div>
  <div class="step-labels">
    <span data-s="0">Folder</span><span data-s="1">Match &amp; Artwork</span>
    <span data-s="2">Review</span><span data-s="3">Done</span>
  </div>
</div>


<main>
  <!-- API KEY -->
  <div class="card center-col hidden" id="step-key">
    <img class="key-logo" src="/assets/brand.png" alt="Game Icons Studio">
    <button class="big-btn btn-go" style="margin-bottom:6px;" onclick="showAbout()">&#10067; What is GIS? &mdash; new here? Start with a quick tour</button>
    <h2>Let's get you set up</h2>
    <p class="sub" style="max-width:620px;">Game Icons Studio finds your game covers through <b>SteamGridDB</b>, a free community artwork library. You just need a free API key &mdash; it takes a minute, once.</p>

    <div class="key-cols">
      <div class="key-col">
        <div class="key-col-title">New here?</div>
        <div class="tutorial">
          <div class="tut-step"><span class="tut-num">1</span><span>Open SteamGridDB and click <b>Login</b> (top right).</span></div>
          <div class="tut-step"><span class="tut-num">2</span><span><b>Sign in with Steam</b> &mdash; this creates your free account instantly.</span></div>
          <div class="tut-step"><span class="tut-num">3</span><span>Then come back and use the other button to grab your key.</span></div>
        </div>
        <button class="big-btn btn-go" onclick="openUrl('https://www.steamgriddb.com/')">&#10133; Create a SteamGridDB account</button>
      </div>

      <div class="key-col">
        <div class="key-col-title">Already have an account?</div>
        <div class="tutorial">
          <div class="tut-step"><span class="tut-num">1</span><span>Open your API settings with the button below.</span></div>
          <div class="tut-step"><span class="tut-num">2</span><span>Click <b>Create API Key</b>, then <b>Copy</b> it.</span></div>
          <div class="tut-step"><span class="tut-num">3</span><span>Paste it here and you're ready to go.</span></div>
        </div>
        <button class="big-btn btn-good" onclick="openUrl('https://www.steamgriddb.com/profile/preferences/api')">&#128273; Get my API key</button>
      </div>
    </div>

    <input class="input-path" id="keyInput" placeholder="Paste your API key here" autocomplete="off" />
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="pasteKey()">&#128203; Paste &amp; continue</button>
      <button class="ghost" onclick="saveKey()">Continue</button>
    </div>
    <div id="keyMsg" class="sub"></div>
  </div>

  <!-- NO ARTWORK -->
  <div class="card center-col hidden" id="step-noart">
    <h2>No cover art for this one</h2>
    <p class="sub" id="noartShortcut"></p>
    <div class="noart-preview" id="noartPreview"></div>
    <p class="sub" style="max-width:520px;">SteamGridDB doesn't have any artwork for this game yet, so nobody has uploaded a cover. Game Icons Studio will create a clean placeholder icon with the game's name instead, matching your other icons.</p>
    <div class="btn-row" id="noartBtns">
      <button class="big-btn btn-good" data-nav onclick="acceptNoArt()">&#10022; Generate a placeholder icon</button>
      <button class="ghost" data-nav onclick="showOtherMatches()">Try a different game</button>
    </div>
    <div class="footer-nav">
      <button class="back-btn" onclick="goBack()">&larr; Back</button>
      <button class="back-btn" onclick="goHome()">&#8962; Home</button>
    </div>
  </div>

  <!-- HOME -->
  <div class="card center-col" id="step-home">
    <div class="home-hero">
      <h2>Game Icons Studio</h2>
      <p>Download covers. Replace icons. Modernize your Games folder.</p>
    </div>
    <div class="home-grid">
      <button class="home-btn" data-home="0" onclick="startFullScan()">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><rect x="3" y="4" width="18" height="14" rx="2"/><path d="M3 9h18"/><path d="M8 14h2M12 14h4"/></svg>
        <div class="t">Choose your game shortcuts folder</div>
        <div class="d">Scan every shortcut in your games folder and replace their icons.</div>
      </button>
      <button class="home-btn" data-home="1" onclick="startChangeIcons()">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>
        <div class="t">Change specific icons</div>
        <div class="d">Pick just the shortcuts you want to redo and choose new covers.</div>
      </button>
      <button class="home-btn" data-home="2" onclick="repairIconCache()">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.4l-5.6 5.6a1.5 1.5 0 0 0 2.1 2.1l5.6-5.6a4 4 0 0 0 5.4-5.4l-2.4 2.4-2.1-2.1Z"/></svg>
        <div class="t">Repair icon cache</div>
        <div class="d">Fix blank or stale icons by refreshing the Windows icon cache.</div>
      </button>
    </div>
    <div class="home-tools">
      <button class="ghost tool-btn" onclick="quickReapply()" title="Re-apply your last saved choices">&#8635; Quick re-apply</button>
      <button class="ghost tool-btn" onclick="openHistory()" title="See what you changed and when">&#128340; History</button>
    </div>
    <div class="kbd-hint"><b>&larr; &rarr;</b> move &nbsp; <b>Enter</b> select &nbsp; <b>F</b> fullscreen</div>
  </div>

  <!-- HISTORY -->
  <div class="card center-col hidden" id="step-history">
    <h2>Your icon history</h2>
    <p class="sub">The most recent icon changes you have made.</p>
    <input class="input-path" id="historySearch" placeholder="&#128269; Search history..." oninput="filterHistory()" style="max-width:420px;" />
    <div class="history-list" id="historyList"></div>
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="goHome()">&#8962; Back to home</button>
    </div>
  </div>

  <!-- WHAT IS GIS -->
  <div class="card hidden" id="step-about">
    <h2 style="text-align:center;">What is GIS? <span style="color:var(--muted);font-size:1rem;">(Game Icons Studio)</span></h2>
    <p class="sub" style="text-align:center;max-width:720px;margin:0 auto 8px;">A quick tour, so you know what this app does and how to use it.</p>

    <div class="about-wrap">
      <div class="about-card">
        <div class="about-h">&#127918; What it is</div>
        <p>Game Icons Studio turns the plain, generic icons of your game shortcuts into proper game cover art, so your Games folder looks like a real shelf. It finds the right artwork automatically, builds clean Windows icons, and applies them for you.</p>
      </div>

      <div class="about-card">
        <div class="about-h">&#128268; Where the art comes from</div>
        <p>Covers are pulled from <b>SteamGridDB</b> (steamgriddb.com), a free community library of game artwork. You sign up once and paste a free <b>API key</b>; the app uses it to search and download covers. Your key stays on your PC.</p>
      </div>

      <div class="about-card">
        <div class="about-h">&#9889; How it works (3 steps)</div>
        <p><b>1. Choose a folder</b> of game shortcuts (.lnk). The app scans them and matches each to a game.<br>
        <b>2. Review</b> the covers it picked. Keep the ones you like, change the ones you do not.<br>
        <b>3. Apply.</b> The app safely backs up your old icons, then sets the new ones and refreshes Windows.</p>
      </div>

      <div class="about-card">
        <div class="about-h">&#129513; What each button does</div>
        <p><b>Choose your game shortcuts folder</b> &mdash; full scan of a whole folder.<br>
        <b>Change specific icons</b> &mdash; pick just a few shortcuts to redo.<br>
        <b>Repair icon cache</b> &mdash; fix blank or stale icons by refreshing the Windows icon cache.<br>
        <b>Quick re-apply</b> &mdash; re-apply your last saved choices in one click (handy if icons go blank).<br>
        <b>History</b> &mdash; see what you changed, for which game, and when.</p>
      </div>

      <div class="about-card">
        <div class="about-h">&#128202; The summary screen</div>
        <p>After applying, you see a summary of how many icons were updated, matched, made from a placeholder, skipped or failed. From there you can <b>Finish</b>, or <b>Return to the grid</b> to review and change any icons again.</p>
      </div>

      <div class="about-card">
        <div class="about-h">&#128190; Safe and non-destructive</div>
        <p>Game Icons Studio only changes a shortcut's icon &mdash; nothing is deleted and your shortcuts keep working exactly as before. It just points each shortcut at a new icon image.</p>
      </div>
    </div>

    <div class="btn-row">
      <button class="big-btn btn-good" data-nav onclick="aboutDone()">&#8962; Go to home to start</button>
    </div>
  </div>

  <!-- CONVERT SUCCESS -->
  <div class="card center-col hidden" id="step-convert-ok">
    <div class="success-mark">&#10003;</div>
    <h2>Conversion successful!</h2>
    <p class="sub" id="convertOkCount"></p>
    <p class="sub" style="max-width:600px;">All your shortcuts are now standard <b>.lnk</b> files, so every icon can be customized properly. They keep working exactly as before.</p>
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="runScan()">Continue &rarr;</button>
    </div>
  </div>

  <!-- REPAIR RESULT -->
  <div class="card center-col hidden" id="step-restore-ok">
    <div class="success-mark">&#10003;</div>
    <h2>Done</h2>
    <p class="sub" id="restoreResultMsg" style="max-width:620px;"></p>
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="goHome()">&#8962; Back to home</button>
    </div>
  </div>

  <!-- FOLDER HEALTH -->
  <div class="card center-col hidden" id="step-health">
    <h2>Here's what I found</h2>
    <p class="sub">A quick look at your folder before we start.</p>
    <div class="health-row" id="healthRow"></div>
    <div id="healthNote" class="sub" style="max-width:600px;"></div>
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="healthContinue()">Continue &rarr;</button>
      <button class="ghost" onclick="goHome()">Cancel</button>
    </div>
  </div>

  <!-- APPLY CONFIRM -->
  <div class="card center-col hidden" id="step-confirm-apply">
    <div class="success-mark" style="background:linear-gradient(135deg,#3b82f6,#2563eb);">&#9881;</div>
    <h2>Ready to apply</h2>
    <p class="sub" id="applyConfirmText" style="max-width:620px;"></p>
    <p class="sub" style="max-width:620px;">This sets the new icons on your shortcuts. They keep working exactly as before.</p>
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="confirmApplyYes()">Yes, apply now</button>
      <button class="ghost g-bad" onclick="goReview()">Go back</button>
    </div>
  </div>

  <!-- NEW GAMES DETECTED -->
  <div class="card center-col hidden" id="step-newgames">
    <img class="key-logo" src="/assets/brand.png" alt="">
    <h2>New games found</h2>
    <p class="sub" id="newGamesCount" style="max-width:620px;"></p>
    <p class="sub" style="max-width:620px;">Want me to set icons just for the new ones, or scan the whole folder?</p>
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="scanNewOnly()">Just the new games</button>
      <button class="ghost" onclick="scanAllInstead()">Scan everything</button>
    </div>
    <div class="footer-nav"><button class="back-btn" onclick="goHome()">&#8962; Home</button></div>
  </div>

  <!-- MEMORY PROMPT -->
  <div class="card center-col hidden" id="step-memory">
    <img class="key-logo" src="/assets/brand.png" alt="">
    <h2>Welcome back!</h2>
    <p class="sub" id="memoryCount" style="max-width:620px;"></p>
    <p class="sub" style="max-width:620px;">I remember the games and covers you picked last time. Want me to use those again, or start fresh?</p>
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="memoryLoad()">&#10003; Use my previous choices</button>
      <button class="ghost g-bad" onclick="memoryReset()">Start over from scratch</button>
    </div>
    <div class="footer-nav"><button class="back-btn" onclick="goHome()">&#8962; Home</button></div>
  </div>

  <!-- CONVERT INTERNET SHORTCUTS -->
  <div class="card center-col hidden" id="step-convert">
    <img class="key-logo" src="/assets/brand.png" alt="">
    <h2>We found some launcher shortcuts</h2>
    <p class="sub" style="max-width:620px;">Some of your shortcuts are <b>Internet Shortcuts</b> (.url) instead of standard Windows shortcuts (.lnk). Windows won't let us give those a custom icon as they are.</p>
    <p class="sub" style="max-width:620px;">Game Icons Studio can convert them automatically. <b>Your shortcuts will keep working exactly the same</b> &mdash; they'll just become standard shortcuts that can show your new icons.</p>
    <div id="convertCount" class="sub"></div>
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="doConvert()">Convert &amp; continue</button>
      <button class="ghost" onclick="skipConvert()">Skip, scan only .lnk files</button>
    </div>
    <div class="footer-nav"><button class="back-btn" onclick="goHome()">&#8962; Home</button></div>
  </div>

  <!-- FOLDER -->
  <div class="card center-col hidden" id="step-folder">
    <h2>Choose your games folder</h2>
    <p class="sub">Select the folder that holds your game shortcuts (.lnk), or paste its path.</p>
    <button class="big-btn" onclick="browseFolder()">&#128193; Browse for folder...</button>
    <input class="input-path" id="folderInput" placeholder="...or paste a folder path here and press Enter" />
    <div id="folderPath" class="sub"></div>
    <div class="btn-row">
      <button class="big-btn hidden" id="scanBtn" onclick="startScan()">Scan this folder &rarr;</button>
    </div>
    <div class="footer-nav"><button class="back-btn" onclick="goBack()">&larr; Back</button></div>
  </div>

  <!-- LOADING / SCAN -->
  <div class="card center-col hidden" id="step-loading">
    <div class="loading">
      <div class="spinner"></div>
      <div id="loadingMsg" class="phase-text">Working...</div>
      <div class="bigbar"><div class="bigbar-fill" id="loadFill"></div></div>
      <div id="loadDetail" class="sub"></div>
      <div class="feed" id="autoFeed"></div>
    </div>
    <div class="footer-nav" id="loadNav" style="margin-top:8px;">
      <button class="back-btn" onclick="goHome()">&#8962; Home</button>
    </div>
  </div>

  <!-- CONFIRM -->
  <div class="card hidden" id="step-confirm">
    <div id="autoBanner" class="auto-banner hidden"></div>
    <h2 id="confirmTitle">Do you like this icon?</h2>
    <p class="sub" id="confirmShortcut"></p>
    <div class="match-row">
      <img class="cover-main" id="confirmCover" src="" alt="">
      <div class="match-info">
        <div class="game-name" id="confirmGame"></div>
        <div class="game-year" id="confirmYear"></div>
        <div class="hint">Highest-confidence match with its best Grid cover.</div>
      </div>
    </div>
    <div class="btn-row" id="confirmBtns">
      <button class="big-btn btn-good" data-nav onclick="acceptMatch()">&#10003; Looks good</button>
      <button class="ghost g-warn" data-nav onclick="showArtwork()">Choose a different cover</button>
      <button class="ghost g-bad" data-nav onclick="showOtherMatches()">The game is wrong</button>
    </div>
    <div class="btn-row" style="margin-top:-6px;">
      <button class="ghost auto-btn" data-nav onclick="chooseAllAuto()" title="Let the app pick every confident match and only stop for uncertain ones">&#9889; Choose all games &amp; covers automatically</button>
    </div>
    <div class="footer-nav">
      <button class="back-btn" onclick="goBack()">&larr; Back</button>
      <button class="back-btn rtg" onclick="returnToGrid()" style="display:none;">&#9783; Return to grid</button>
      <span class="kbd-hint"><b>&larr; &rarr;</b> move &nbsp; <b>Enter</b> pick &nbsp; <b>A</b> auto-all &nbsp; <b>Backspace</b> back</span>
    </div>
  </div>

  <!-- ARTWORK -->
  <div class="card hidden" id="step-artwork">
    <h2>Choose a cover</h2>
    <p class="sub" id="artworkGame"></p>
    <div class="view-toggle">
      <button class="ghost vt-btn" id="vtGrid" onclick="setGallery(false)">&#9638; Grid</button>
      <button class="ghost vt-btn" id="vtGallery" onclick="setGallery(true)">&#9635; Gallery</button>
    </div>
    <div class="grid" id="artworkGrid"></div>
    <div class="footer-nav">
      <button class="back-btn" onclick="goBack()">&larr; Back</button>
      <button class="back-btn rtg" onclick="returnToGrid()" style="display:none;">&#9783; Return to grid</button>
      <span class="kbd-hint"><b>Arrows</b> move &nbsp; <b>Enter</b> pick &nbsp; <b>Backspace</b> back</span>
    </div>
  </div>

  <!-- OTHER MATCHES -->
  <div class="card hidden" id="step-matches">
    <h2>Pick the correct game</h2>
    <p class="sub" id="matchesShortcut"></p>
    <div class="grid" id="matchesGrid" style="grid-template-columns:repeat(auto-fill,minmax(170px,1fr));"></div>
    <div class="footer-nav">
      <button class="back-btn" onclick="goBack()">&larr; Back</button>
      <button class="back-btn rtg" onclick="returnToGrid()" style="display:none;">&#9783; Return to grid</button>
      <span class="kbd-hint"><b>Arrows</b> move &nbsp; <b>Enter</b> pick &nbsp; <b>Backspace</b> back</span>
    </div>
  </div>

  <!-- REVIEW -->
  <div class="card hidden" id="step-review">
    <h2>Pick the ones you don't like and change them</h2>
    <p class="sub">Click any icons you are not happy with (they dim when selected), then press "Change these icons". Happy with all of them? Just press Finish.</p>
    <input class="input-path" id="reviewSearch" placeholder="&#128269; Search your games..." oninput="filterReview()" style="max-width:420px;" />
    <div class="grid" id="reviewGrid"></div>
    <div class="btn-row" id="reviewBtns">
      <button class="big-btn btn-good" id="finishBtn" data-nav onclick="applyAll()">FINISH! (Apply all changes)</button>
      <button class="ghost g-warn" id="changeBtn" data-nav onclick="changeSelected()">Change these icons</button>
      <button class="ghost g-bad" data-nav onclick="goHome()">Start over</button>
    </div>
    <div class="footer-nav"><button class="back-btn" onclick="goBack()">&larr; Back</button></div>
  </div>

  <!-- REPORT -->
  <div class="card center-col hidden" id="step-report">
    <div class="success-mark">&#10003;</div>
    <h2>All done</h2>
    <p class="sub">Here is a summary of this run. You can finish, or go back to the grid to review and change any icons.</p>
    <div class="report-grid" id="reportGrid"></div>
    <div id="statsBox" class="stats-box"></div>
    <div class="btn-row" id="reportBtns">
      <button class="big-btn btn-good" data-nav onclick="finishAndOpen()">&#10003; Finish &amp; open my folder</button>
      <button class="big-btn btn-warn" data-nav onclick="returnToGrid()">&#9635; Return to the grid (review &amp; change)</button>
    </div>
    <div class="btn-row">
      <button class="ghost" data-nav onclick="goHome()">Back to home</button>
    </div>
  </div>
</main>

<script>
PLACEHOLDER_JS
</script>
</body>
</html>
'@
    $js = Get-WebAppJs
    return $html.Replace('PLACEHOLDER_JS', $js)
}

function Get-WebAppJs {
    @'
var state = {
  mode:'full', folder:'', items:[], pos:0, picks:{}, history:[],
  focusIdx:0, total:0, autoAll:false, zoom:1, homeFocus:0, report:null, editQueue:[], editReturnToReview:false, reviewSelected:{}, memoryAsked:false, useMemory:false, _applyConfirmed:false, onlyNew:false, gallery:false, _history:[], _autoApplyAfterScan:false
};
var coverCache = {};

function $(id){ return document.getElementById(id); }
var SCREENS = ['step-convert','step-convert-ok','step-memory','step-newgames','step-restore-ok','step-history','step-about','step-health','step-confirm-apply','step-key','step-noart','step-home','step-folder','step-loading','step-confirm','step-artwork','step-matches','step-review','step-report'];
function show(id){
  SCREENS.forEach(function(s){ $(s).classList.add('hidden'); });
  $(id).classList.remove('hidden');
  $('progressWrap').classList.toggle('hidden', (id === 'step-home' || id === 'step-key'));
  $('homeBtn').style.display = (id === 'step-key') ? 'none' : '';
  var aB = $('aboutBtn'); if (aB){ aB.style.display = (id === 'step-key' || id === 'step-about') ? 'none' : ''; }
  var sBtn = $('summaryBtn');
  if (sBtn){
    var canSummary = state.report && id !== 'step-report' && id !== 'step-key' && id !== 'step-home';
    sBtn.style.display = canSummary ? '' : 'none';
  }
  if (typeof updateRtgButtons === 'function') updateRtgButtons();
}
function visible(id){ return !$(id).classList.contains('hidden'); }

function setProgress(stage){
  document.querySelectorAll('.step').forEach(function(el){
    var s = +el.dataset.s;
    el.classList.toggle('done', s < stage);
    el.classList.toggle('active', s === stage);
  });
  document.querySelectorAll('.step-labels span').forEach(function(el){
    el.classList.toggle('active', +el.dataset.s === stage);
  });
}

function setLoading(msg, detail, pct){
  $('loadingMsg').textContent = msg || 'Working...';
  $('loadingMsg').classList.remove('typed-caret');
  $('loadDetail').textContent = detail || '';
  $('loadFill').style.width = (pct==null?0:pct) + '%';
  $('autoFeed').innerHTML = '';
  show('step-loading');
}
function setLoadProgress(detail, pct){
  $('loadDetail').textContent = detail || '';
  if (pct != null) $('loadFill').style.width = pct + '%';
}

// ---- theme / zoom / fullscreen ----
var THEMES = [
  { id:'glass',         name:'Glass',         icon:'\u25C8' },
  { id:'dark',          name:'Dark',          icon:'\u263E' },
  { id:'light',         name:'Light',         icon:'\u2600' },
  { id:'modern-dark',   name:'Modern Dark',   icon:'\u25D2' },
  { id:'modern-light',  name:'Modern Light',  icon:'\u25D3' },
  { id:'gaming',        name:'Gaming',        icon:'\u25BC' },
  { id:'minimal',       name:'Minimal',       icon:'\u25A1' }
];
var themeIdx = 0;
function applyTheme(){
  var t = THEMES[themeIdx];
  document.documentElement.setAttribute('data-theme', t.id);
  $('themeIcon').innerHTML = t.icon;
  $('themeTxt').textContent = t.name;
  // Remember the choice so it returns next launch.
  try { localStorage.setItem('gis-theme', t.id); } catch(e){}
}
function cycleTheme(){
  themeIdx = (themeIdx + 1) % THEMES.length;
  applyTheme();
}
function loadSavedTheme(){
  var saved = null;
  try { saved = localStorage.getItem('gis-theme'); } catch(e){}
  if (saved){
    for (var i=0;i<THEMES.length;i++){ if (THEMES[i].id === saved){ themeIdx = i; break; } }
  }
  applyTheme();
}
function zoomIn(){ state.zoom = Math.min(1.7, state.zoom + 0.1); applyZoom(); }
function zoomOut(){ state.zoom = Math.max(0.7, state.zoom - 0.1); applyZoom(); }
function applyZoom(){
  document.documentElement.style.setProperty('--fs', (16*state.zoom).toFixed(1)+'px');
  try { localStorage.setItem('gis-zoom', String(state.zoom)); } catch(e){}
}
function toggleFullscreen(){
  if (!document.fullscreenElement){ document.documentElement.requestFullscreen().catch(function(){}); }
  else { document.exitFullscreen().catch(function(){}); }
}
document.addEventListener('fullscreenchange', function(){
  $('fsBtn').innerHTML = document.fullscreenElement ? '&#9974; Exit Fullscreen' : '&#9974; Fullscreen';
});

function api(path, body){
  return fetch(path, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body||{}) })
    .then(function(r){ return r.json(); });
}
function shutdownMessage(){
  document.body.innerHTML = '<div style="display:flex;height:100vh;align-items:center;justify-content:center;color:#9aa3ad;font-family:Segoe UI,sans-serif;font-size:18px;">All set! You can close this tab.</div>';
  // Attempt to close the tab (works when allowed by the browser).
  setTimeout(function(){ try { window.open('', '_self'); window.close(); } catch(e){} }, 300);
}
function quitApp(){ api('/api/quit', {}).finally(shutdownMessage); }
function finishAndOpen(){
  document.body.style.opacity = '0.6';
  api('/api/finish', {}).finally(shutdownMessage);
}


// ---- image preloading ----
function preloadItem(it, full){
  if (!it || !it.sections) return;
  it.sections.forEach(function(sec, si){
    var covers = sec.covers || [];
    // During scan we only warm the best cover of the best section to
    // keep bandwidth free; the rest preload when the user arrives.
    var limit = full ? covers.length : ((si === 0) ? 1 : 0);
    for (var i = 0; i < Math.min(limit, covers.length); i++){
      var c = covers[i];
      if (c.thumb && !coverCache[c.thumb]){
        var img = new Image(); img.src = c.thumb; coverCache[c.thumb] = img;
      }
    }
  });
}
function preloadAround(pos){
  // Fully preload the current item (all covers) and lightly warm the next two.
  if (state.items[pos]) preloadItem(state.items[pos], true);
  for (var k = pos+1; k < Math.min(state.items.length, pos+3); k++){ preloadItem(state.items[k], false); }
}

// ---- API KEY ----
function checkKey(){
  api('/api/key-status', {}).then(function(res){
    if (res.hasKey){ goHome(); } else { show('step-key'); setTimeout(function(){ $('keyInput').focus(); }, 100); }
  });
}
function openUrl(u){ try { window.open(u, '_blank'); } catch(e){} }
function pasteKey(){
  if (navigator.clipboard && navigator.clipboard.readText){
    navigator.clipboard.readText().then(function(t){
      $('keyInput').value = (t||'').trim();
      saveKey();
    }).catch(function(){ $('keyMsg').textContent = 'Could not read the clipboard. Paste with Ctrl+V, then Continue.'; });
  } else {
    $('keyMsg').textContent = 'Paste with Ctrl+V into the box, then press Continue.';
  }
}
function saveKey(){
  var key = $('keyInput').value.trim();
  if (!key){ $('keyMsg').textContent = 'Please paste your API key first.'; return; }
  $('keyMsg').textContent = 'Checking your key...';
  api('/api/save-key', { key: key }).then(function(res){
    if (res.ok){ $('keyMsg').textContent = ''; goHome(); }
    else { $('keyMsg').textContent = res.error || 'That key did not work.'; }
  });
}

// ---- HOME ----
function goHome(){
  state.autoAll = false;
  setProgress(0);
  // If there is still no key, stay on the key screen.
  show('step-home');
  state.homeFocus = 0; focusHome();
}
function focusHome(){
  document.querySelectorAll('.home-btn').forEach(function(b,i){ b.classList.toggle('focus', i===state.homeFocus); });
}


// ---- Quick re-apply (#10) ----
function quickReapply(){
  setLoading('Getting ready to re-apply...', 'Loading your last folder and saved choices.', 0);
  api('/api/last-folder', {}).then(function(res){
    if (!(res.ok && res.folder)){
      $('restoreResultMsg').textContent = 'There is no previous folder to re-apply yet. Scan a folder first.';
      show('step-restore-ok');
      return;
    }
    api('/api/saved-status', {}).then(function(st){
      if (!st || !st.ok || st.count === 0){
        $('restoreResultMsg').textContent = 'You have no saved choices to re-apply yet.';
        show('step-restore-ok');
        return;
      }
      // Reuse the full pipeline with memory on, applying everything
      // automatically end to end.
      state.folder = res.folder;
      state.mode = 'full';
      state.onlyNew = false;
      state.memoryAsked = true;
      state.useMemory = true;
      state.autoAll = true;          // auto-accept remembered/best picks
      state._applyConfirmed = true;  // skip the confirm gate for a one-click redo
      doScan();
    });
  });
}

function showAbout(){ show('step-about'); setNavFocus(null); window.scrollTo(0,0); var c=$('step-about'); if(c) c.scrollTop=0; }
function aboutDone(){
  // If the user has not set an API key yet, send them back to setup;
  // otherwise go to the home screen.
  api('/api/key-status', {}).then(function(res){
    if (res && res.hasKey){ goHome(); } else { show('step-key'); }
  }).catch(function(){ goHome(); });
}

// ---- History (#15) ----
function openHistory(){
  setLoading('Loading your history...', '', 0);
  api('/api/history', {}).then(function(res){
    var list = (res && res.entries) ? res.entries : [];
    state._history = list;
    renderHistory(list);
    show('step-history');
  }).catch(function(){ goHome(); });
}
function renderHistory(list){
  var wrap = $('historyList'); wrap.innerHTML = '';
  if (!list.length){
    wrap.innerHTML = '<div class="sub" style="text-align:center;padding:24px;">No history yet. Once you apply icons, your changes show up here.</div>';
    return;
  }
  list.forEach(function(h){
    var row = document.createElement('div');
    row.className = 'history-row';
    row.dataset.search = ((h.name||'') + ' ' + (h.game||'')).toLowerCase();
    var thumb = h.url ? '<img src="'+h.url+'" loading="lazy" class="hist-thumb">' : '<div class="hist-thumb hist-ph"></div>';
    row.innerHTML = thumb +
      '<div class="hist-info"><div class="hist-name">' + (h.name||'') + '</div>' +
      '<div class="hist-sub">' + (h.game ? h.game : 'placeholder') + (h.date ? (' &middot; ' + h.date) : '') + '</div></div>';
    wrap.appendChild(row);
  });
}
function filterHistory(){
  var q = ($('historySearch').value||'').trim().toLowerCase();
  document.querySelectorAll('#historyList .history-row').forEach(function(el){
    var hay = el.dataset.search || '';
    el.style.display = (!q || hay.indexOf(q) >= 0) ? '' : 'none';
  });
}


function repairIconCache(){
  setLoading('Repairing the Windows icon cache...', 'This refreshes how icons are shown.', 50);
  api('/api/repair-cache', {}).then(function(res){
    $('restoreResultMsg').textContent = res && res.ok
      ? 'Icon cache refreshed. Your icons should look correct now. If not, sign out and back in once.'
      : 'Could not refresh the icon cache automatically.';
    show('step-restore-ok');
  }).catch(function(){ goHome(); });
}

// ---- FULL SCAN flow ----
function startFullScan(){
  state.mode = 'full';
  state.onlyNew = false; state.memoryAsked = false;
  setProgress(0);
  show('step-folder');
  $('folderPath').textContent = '';
  $('scanBtn').classList.add('hidden');
  $('folderInput').value = '';
  api('/api/last-folder', {}).then(function(res){
    if (res.ok && res.folder){
      state.folder = res.folder;
      $('folderInput').value = res.folder;
      $('folderPath').textContent = 'Last used folder ready. Press Scan, or browse/paste another.';
      $('scanBtn').classList.remove('hidden');
      maybeOfferNewGames();
    }
  });
}
function browseFolder(){
  setLoading('Opening the folder window...', 'A Windows folder window will appear in front. Pick your games folder and click OK.', null);
  api('/api/browse-folder', {}).then(function(){
    pollDialog(function(res){
      if (res.ok && res.folder){
        state.folder = res.folder;
        folderReady(res.folder);
      } else {
        show('step-folder');
        $('folderPath').textContent = 'No folder chosen. Try again, or paste a path above.';
      }
    });
  });
}
// Land on the folder screen with everything available, then start the
// scan automatically (no extra Scan click needed).
function folderReady(folder){
  show('step-folder');
  $('folderInput').value = folder;
  $('folderPath').textContent = 'Folder ready. Starting...';
  $('scanBtn').classList.remove('hidden');
  // If this folder was scanned before and has new games, offer that
  // choice; otherwise go straight into scanning.
  api('/api/new-games-count', { folder: folder }).then(function(res){
    if (res && res.ok && res.knownFolder && res.newCount > 0){
      $('newGamesCount').textContent = 'You have ' + res.newCount + ' new game' + (res.newCount===1?'':'s') +
        ' in this folder since your last visit.';
      show('step-newgames');
    } else {
      startScan();
    }
  }).catch(function(){ startScan(); });
}

// Polls the async native dialog without blocking. Keeps the browser
// responsive while the Windows window is open, and refocuses the
// browser when it closes.
function pollDialog(done){
  var tick = function(){
    api('/api/dialog-status', {}).then(function(res){
      if (res.status === 'done'){
        try { window.focus(); } catch(e){}
        done(res);
      } else {
        setTimeout(tick, 350);
      }
    }).catch(function(){ setTimeout(tick, 500); });
  };
  setTimeout(tick, 350);
}
function tryTypedFolder(){
  var v = $('folderInput').value.trim();
  if (!v) return;
  api('/api/validate-folder', { folder: v }).then(function(res){
    if (res.ok){
      state.folder = res.folder;
      folderReady(res.folder);
    } else {
      $('folderPath').textContent = 'That path does not exist. Check it and try again.';
    }
  });
}

function startScan(){
  setProgress(0);
  setLoading('Checking your folder...', 'Taking a quick look...', 0);
  api('/api/folder-health', { folder: state.folder }).then(function(h){
    var row = $('healthRow'); row.innerHTML = '';
    var cards = [
      ['Standard shortcuts', h.lnk||0, 'var(--good)'],
      ['Launcher shortcuts (.url)', h.url||0, 'var(--warn)'],
      ['Broken / missing target', h.broken||0, (h.broken>0?'var(--bad)':'var(--muted)')]
    ];
    cards.forEach(function(c){
      var d=document.createElement('div'); d.className='health-card';
      d.innerHTML='<div class="health-n" style="color:'+c[2]+'">'+c[1]+'</div><div class="health-l">'+c[0]+'</div>';
      row.appendChild(d);
    });
    var notes=[];
    if ((h.url||0)>0){ notes.push('Launcher shortcuts will be offered for conversion so their icons can be customized.'); }
    if ((h.broken||0)>0){ notes.push('Some shortcuts point to a missing file; those will be skipped safely.'); }
    if (!notes.length){ notes.push('Everything looks good!'); }
    $('healthNote').textContent = notes.join(' ');
    show('step-health');
  }).catch(function(){ afterHealth(); });
}
function healthContinue(){ afterHealth(); }
function afterHealth(){
  setLoading('Checking your folder...', 'Looking at your shortcuts...', 0);
  api('/api/check-url-shortcuts', { folder: state.folder }).then(function(chk){
    if (chk && chk.ok && chk.urlCount > 0){
      $('convertCount').textContent = 'Found ' + chk.urlCount + ' launcher shortcut' + (chk.urlCount===1?'':'s') +
        (chk.lnkCount>0 ? (' and ' + chk.lnkCount + ' standard shortcut' + (chk.lnkCount===1?'':'s') + '.') : '.');
      show('step-convert');
    } else {
      runScan();
    }
  }).catch(function(){ runScan(); });
}
function doConvert(){
  setLoading('Converting your shortcuts...', 'This keeps them working and lets them show new icons.', 30);
  api('/api/convert-shortcuts', { folder: state.folder }).then(function(res){
    var n = (res && res.converted) ? res.converted : 0;
    showConvertSuccess(n);
  }).catch(function(){ runScan(); });
}
function showConvertSuccess(n){
  $('convertOkCount').textContent = n
    ? ('Converted ' + n + ' shortcut' + (n===1?'':'s') + ' to standard .lnk format.')
    : 'Your shortcuts are ready.';
  show('step-convert-ok');
}
function skipConvert(){ runScan(); }
function runScan(){
  // Offer to reuse remembered choices (only for full-folder mode, once).
  if (state.mode === 'full' && !state.memoryAsked){
    state.memoryAsked = true;
    setLoading('Checking your saved choices...', '', 0);
    api('/api/saved-status', {}).then(function(res){
      if (res && res.ok && res.count > 0){
        $('memoryCount').textContent = 'You have ' + res.count + ' remembered ' + (res.count===1?'choice':'choices') + ' from before.';
        show('step-memory');
      } else {
        state.useMemory = false; doScan();
      }
    }).catch(function(){ state.useMemory = false; doScan(); });
    return;
  }
  doScan();
}
function memoryLoad(){ state.useMemory = true; doScan(); }
function memoryReset(){
  state.useMemory = false;
  setLoading('Starting fresh...', 'Clearing your previous choices...', 0);
  api('/api/reset-choices', {}).then(function(){ doScan(); }).catch(function(){ doScan(); });
}
function doScan(){
  setProgress(0);
  setLoading('Scanning SteamGridDB for your games...', 'Reading your folder...', 0);
  var payload = { folder: state.folder };
  if (state.onlyNew){ payload.onlyNew = true; }
  api('/api/scan-begin', payload).then(function(res){
    if (!res.ok){ show('step-folder'); $('folderPath').textContent = res.error || 'Scan failed.'; return; }
    beginScanLoop(res.total);
  });
}

// ---- New-game detection (#13) ----
function maybeOfferNewGames(){
  if (!state.folder) return;
  api('/api/new-games-count', { folder: state.folder }).then(function(res){
    if (res && res.ok && res.knownFolder && res.newCount > 0){
      $('newGamesCount').textContent = 'You have ' + res.newCount + ' new game' + (res.newCount===1?'':'s') +
        ' in this folder since your last visit.';
      show('step-newgames');
    }
  }).catch(function(){});
}
function scanNewOnly(){
  state.mode = 'full';
  state.onlyNew = true;
  state.memoryAsked = true;
  state.useMemory = true;   // reuse remembered choices for old ones (they are skipped anyway)
  doScan();
}
function scanAllInstead(){
  state.onlyNew = false;
  startScan();
}

// ---- CHANGE ICONS flow ----
function startChangeIcons(){
  state.mode = 'change';
  setProgress(0);
  setLoading('Opening the file window...', 'A Windows window will appear in front. Ctrl+click the shortcuts you want to redo, then click Open.', null);
  api('/api/change-files', {}).then(function(){
    pollDialog(function(res){
      if (!res.ok || !res.files || !res.files.length){ goHome(); return; }
      setLoading('Scanning SteamGridDB for your games...', 'Reading the files you picked...', 0);
      api('/api/scan-files-begin', { files: res.files }).then(function(r2){
        if (!r2.ok){ goHome(); alert(r2.error || 'Could not read those files.'); return; }
        beginScanLoop(r2.total);
      });
    });
  });
}

// ---- shared scan loop ----
function beginScanLoop(total){
  state.items = []; state.pos = 0; state.picks = {}; state.history = [];
  state.total = total || 0;
  if (state.total === 0){ goHome(); alert('No matchable games were found.'); return; }
  var est = estimateSeconds(state.total, 0.6);
  setLoading('Scanning your games...', 'About ' + est + ' for ' + state.total + ' game' + (state.total===1?'':'s') + '.', 0);
  scanStep(0);
}
function estimateSeconds(count, perItem){
  var secs = Math.max(1, Math.round(count * perItem));
  if (secs < 60) return 'about ' + secs + ' second' + (secs===1?'':'s');
  var m = Math.round(secs/60);
  return 'about ' + m + ' minute' + (m===1?'':'s');
}
function scanStep(i){
  api('/api/scan-step', { i: i }).then(function(res){
    if (!res.ok){ goHome(); alert(res.error || 'Scan failed.'); return; }
    if (res.item){ state.items.push(res.item); preloadItem(res.item); }
    var pct = res.total ? Math.round(res.current/res.total*100) : 0;
    setLoadProgress('Found ' + res.current + ' of ' + res.total + ':  ' + (res.label||''), pct);
    if (res.done || res.current >= res.total){ preloadAround(0); enterItem(0); }
    else { setTimeout(function(){ scanStep(i+1); }, 0); }
  });
}

function currentItem(){ return state.items[state.pos]; }

function applyRememberedCover(it){
  // Make the remembered cover the selected one. If the scan's sections
  // don't already include it, inject a one-cover section so apply uses
  // exactly the URL the user picked last time.
  var url = it.savedUrl;
  var gName = it.savedGameName || it.name;
  if (!it.sections) it.sections = [];
  var foundG = -1, foundC = -1;
  for (var g=0; g<it.sections.length; g++){
    var covers = it.sections[g].covers || [];
    for (var c=0; c<covers.length; c++){
      if (covers[c].url === url){ foundG = g; foundC = c; break; }
    }
    if (foundG >= 0) break;
  }
  if (foundG >= 0){
    state.picks[it.index] = { game: foundG+1, cover: foundC+1 };
  } else {
    it.sections.unshift({ gameId:0, gameName:gName, year:0, covers:[{ url:url, thumb:url, score:100 }] });
    state.picks[it.index] = { game:1, cover:1 };
  }
}

function enterItem(pos){
  state.pos = pos;
  setProgress(1);
  preloadAround(pos);
  var it = currentItem();
  if (!it){ goReview(); return; }
  if (!state.picks[it.index]) state.picks[it.index] = { game:1, cover:1 };

  // Skip already-done: if the user chose to reuse memory and this game
  // has a remembered cover, apply it and move on without asking.
  if (state.useMemory && !state.editReturnToReview && it.remembered && it.savedUrl){
    applyRememberedCover(it);
    if (state.autoAll){ updateAutoBanner(it.savedGameName ? (it.savedGameName + ' (saved)') : (it.name + ' (saved)')); }
    if (state.pos + 1 >= state.items.length){ goReview(); }
    else { setTimeout(function(){ enterItem(state.pos+1); }, 60); }
    return;
  }

  if (state.autoAll){
    var noArt = (!it.sections || !it.sections.length);
    // Permissive: accept the top match (or a placeholder when there is
    // no artwork at all). Mistakes are fixable later via Change Icons.
    if (noArt || it.autoConfident){
      state.picks[it.index] = { game:1, cover:1 };
      updateAutoBanner(noArt ? (it.name + ' (placeholder)') : it.sections[0].gameName);
      if (state.pos + 1 >= state.items.length){ goReview(); }
      else { setTimeout(function(){ enterItem(state.pos+1); }, 90); }
      return;
    }
  }
  renderConfirm();
}

function chooseAllAuto(){
  state.autoAll = true;
  // Show the auto progress screen with a clear banner, then run through.
  show('step-loading');
  $('loadingMsg').textContent = 'Choosing your games and covers automatically';
  $('loadDetail').textContent = 'I will only stop to ask if I am really not sure about a game.';
  $('loadFill').style.width = '0%';
  $('autoFeed').innerHTML = '';
  setTimeout(function(){ enterItem(state.pos); }, 300);
}
function updateAutoBanner(name){
  var pct = state.items.length ? Math.round((state.pos+1)/state.items.length*100) : 0;
  $('loadFill').style.width = pct + '%';
  $('loadDetail').textContent = 'Matched ' + (state.pos+1) + ' of ' + state.items.length;
  var feed = $('autoFeed');
  var line = document.createElement('div');
  line.innerHTML = '<b>&#10003;</b> ' + name;
  feed.insertBefore(line, feed.firstChild);
  while (feed.children.length > 4) { feed.removeChild(feed.lastChild); }
}

function renderConfirm(){
  var it = currentItem();
  var pick = state.picks[it.index];
  if (!it.sections || !it.sections.length){ renderNoArt(); return; }
  var sec = it.sections[pick.game-1] || it.sections[0];
  var cover = sec.covers[pick.cover-1] || sec.covers[0];
  $('autoBanner').classList.toggle('hidden', !state.autoAll);
  if (state.autoAll){ $('autoBanner').innerHTML = '&#9889; Auto mode is on. I was not sure about this one, so please confirm it.'; }
  $('confirmTitle').textContent = state.autoAll ? "Not sure about this one - do you like it?" : 'Do you like this icon?';
  $('confirmShortcut').textContent = 'Shortcut ' + (state.pos+1) + ' of ' + state.items.length + ':  ' + it.name;
  $('confirmCover').src = cover ? cover.thumb : '';
  $('confirmGame').textContent = sec.gameName;
  $('confirmYear').textContent = sec.year > 0 ? ('Released ' + sec.year) : '';
  show('step-confirm');
  setNavFocus('confirmBtns', 0);
}

function renderNoArt(){
  var it = currentItem();
  $('noartShortcut').textContent = 'Shortcut ' + (state.pos+1) + ' of ' + state.items.length + ':  ' + it.name;
  $('noartPreview').textContent = it.name;
  show('step-noart');
  setNavFocus('noartBtns', 0);
}
function acceptNoArt(){
  // mark placeholder choice (no sections) and move on
  acceptMatch();
}

function acceptMatch(){
  if (state.editReturnToReview){ nextInEditQueue(); return; }
  if (state.pos + 1 >= state.items.length){ goReview(); }
  else { state.history.push(state.pos); enterItem(state.pos+1); }
}

function setGallery(on){
  state.gallery = !!on;
  var grid = $('artworkGrid');
  if (grid){ grid.classList.toggle('gallery', state.gallery); }
  var g = $('vtGrid'), gal = $('vtGallery');
  if (g){ g.classList.toggle('active', !state.gallery); }
  if (gal){ gal.classList.toggle('active', state.gallery); }
  try { localStorage.setItem('gis-gallery', state.gallery ? '1':'0'); } catch(e){}
}
function showArtwork(){
  var it = currentItem();
  var pick = state.picks[it.index];
  var sec = it.sections[pick.game-1] || it.sections[0];
  $('artworkGame').textContent = sec.gameName + (sec.year>0?(' ('+sec.year+')'):'');
  var grid = $('artworkGrid'); grid.innerHTML = '';
  sec.covers.forEach(function(c,i){
    var d = document.createElement('div');
    d.className = 'tile' + (i===(pick.cover-1)?' sel':'');
    d.tabIndex = 0;
    d.innerHTML = '<img src="'+c.thumb+'" loading="eager">';
    d.onclick = function(){ pick.cover = i+1; acceptMatch(); };
    grid.appendChild(d);
  });
  state.focusIdx = pick.cover-1; show('step-artwork');
  setGallery(state.gallery);
  focusTiles('#artworkGrid');
}

function showOtherMatches(){
  var it = currentItem();
  $('matchesShortcut').textContent = 'Which game is "' + it.name + '"?';
  var grid = $('matchesGrid'); grid.innerHTML = '';
  var cands = it.candidateGames || [];
  if (!cands.length && it.sections && it.sections.length){
    // fall back to the single known section
    cands = [{ gameId: it.sections[0].gameId, gameName: it.sections[0].gameName, year: it.sections[0].year }];
  }
  cands.forEach(function(g, gi){
    var d = document.createElement('div');
    d.className = 'tile'; d.tabIndex = 0;
    d.innerHTML = '<div style="width:100%;aspect-ratio:1;border-radius:8px;background:var(--panel);display:flex;align-items:center;justify-content:center;color:var(--muted);font-size:.8rem;">loading...</div>' +
      '<div style="font-size:.82rem;margin-top:6px;text-align:center;">'+g.gameName+
      (g.year>0?(' <span style="color:var(--muted)">('+g.year+')</span>'):'')+'</div>';
    d.onclick = function(){ pickGame(it, g); };
    grid.appendChild(d);
    // lazily fetch one preview cover per candidate
    api('/api/game-covers', { gameId: g.gameId }).then(function(res){
      if (res.ok && res.covers && res.covers.length){
        g._covers = res.covers;
        var img = document.createElement('img');
        img.src = res.covers[0].thumb; img.loading = 'eager';
        var box = d.firstChild;
        if (box) { box.replaceWith(img); }
      }
    });
  });
  state.focusIdx = 0; show('step-matches'); focusTiles('#matchesGrid');
}

function pickGame(it, g){
  // Set this game as the item's chosen section and go to artwork.
  if (g._covers && g._covers.length){
    it.sections = [{ gameId:g.gameId, gameName:g.gameName, year:g.year||0, covers:g._covers }];
    state.picks[it.index] = { game:1, cover:1 };
    showArtwork();
  } else {
    api('/api/game-covers', { gameId: g.gameId }).then(function(res){
      var covers = (res.ok && res.covers) ? res.covers : [];
      it.sections = [{ gameId:g.gameId, gameName:g.gameName, year:g.year||0, covers:covers }];
      state.picks[it.index] = { game:1, cover:1 };
      if (covers.length){ showArtwork(); } else { acceptMatch(); }
    });
  }
}

function goReview(){
  state.autoAll = false;
  // One-click quick re-apply: skip the review screen and apply directly.
  if (state._autoApplyAfterScan){
    state._autoApplyAfterScan = false;
    applyAll();
    return;
  }
  state.editQueue = [];
  state.editReturnToReview = false;
  if (!state.reviewSelected) state.reviewSelected = {};
  setProgress(2);
  var grid = $('reviewGrid'); grid.innerHTML = '';
  state.items.forEach(function(it,i){
    var pick = state.picks[it.index] || {game:1,cover:1};
    var sec = (it.sections && it.sections.length) ? (it.sections[pick.game-1] || it.sections[0]) : null;
    var cover = sec ? (sec.covers[pick.cover-1] || sec.covers[0]) : null;
    var el = document.createElement('div');
    el.className = 'tile rev-tile' + (state.reviewSelected[i] ? ' picked' : '');
    el.tabIndex = 0;
    el.dataset.search = (it.name + ' ' + (sec?sec.gameName:'')).toLowerCase();
    var img = cover
      ? '<img src="'+cover.thumb+'" loading="lazy">'
      : '<div style="width:100%;aspect-ratio:1;border-radius:8px;background:linear-gradient(135deg,#2b3550,#141821);display:flex;align-items:center;justify-content:center;color:#fff;font-size:.8rem;text-align:center;padding:8px;word-break:break-word;">'+it.name+'</div>';
    el.innerHTML = img +
      '<div style="font-size:.78rem;margin-top:6px;text-align:center;">'+it.name+
      '<div style="color:var(--muted)">'+(sec?sec.gameName:'placeholder')+'</div></div>';
    // Click anywhere on the tile to toggle selection for changing.
    el.onclick = function(){ toggleReviewSelect(i, el); };
    el.onkeydown = function(e){ if (e.key==='Enter'){ toggleReviewSelect(i, el); } };
    grid.appendChild(el);
  });
  var sb = $('reviewSearch'); if (sb) sb.value = '';
  updateChangeBtn();
  show('step-review');
  // Always start at the top so the title and instructions are visible.
  var card = $('step-review');
  if (card){ card.scrollTop = 0; }
  var mainEl = document.querySelector('main');
  if (mainEl){ mainEl.scrollTop = 0; }
  window.scrollTo(0, 0);
  setNavFocus('reviewBtns', 0);
}

function toggleReviewSelect(i, el){
  if (state.reviewSelected[i]){ delete state.reviewSelected[i]; el.classList.remove('picked'); }
  else { state.reviewSelected[i] = true; el.classList.add('picked'); }
  updateChangeBtn();
}
function updateChangeBtn(){
  var n = Object.keys(state.reviewSelected || {}).length;
  var changeBtn = $('changeBtn');
  var finishBtn = $('finishBtn');
  if (n > 0){
    if (finishBtn){ finishBtn.style.display = 'none'; }
    if (changeBtn){
      changeBtn.textContent = 'Change these icons (' + n + ')';
      changeBtn.disabled = false;
      changeBtn.classList.remove('ghost');
      changeBtn.classList.add('big-btn','btn-warn');
    }
    setNavFocus('reviewBtns', 0);
  } else {
    if (finishBtn){ finishBtn.style.display = ''; }
    if (changeBtn){
      changeBtn.textContent = 'Change these icons';
      changeBtn.disabled = true;
      changeBtn.classList.remove('big-btn','btn-warn');
      changeBtn.classList.add('ghost');
    }
  }
}
function changeSelected(){
  var idxs = Object.keys(state.reviewSelected || {}).map(function(k){ return parseInt(k,10); }).sort(function(a,b){return a-b;});
  if (!idxs.length){ return; }
  editFromReview(idxs);
}

function filterReview(){
  var q = ($('reviewSearch').value || '').trim().toLowerCase();
  document.querySelectorAll('#reviewGrid .rev-tile').forEach(function(el){
    var hay = el.dataset.search || '';
    el.style.display = (!q || hay.indexOf(q) >= 0) ? '' : 'none';
  });
}

// Edit one or more items, then come back to the review grid.
function editFromReview(indexes){
  state.editQueue = indexes.slice();
  state.editReturnToReview = true;
  // Clear selection so the grid is clean when we return.
  state.reviewSelected = {};
  nextInEditQueue();
}
function returnToGrid(){
  state.editQueue = [];
  state.editReturnToReview = false;
  goReview();
}
function confirmApplyYes(){ state._applyConfirmed = true; applyAll(); }
function returnToSummary(){
  if (!state.report){ return; }
  state.editQueue = [];
  state.editReturnToReview = false;
  state.autoAll = false;
  renderReport(state.report);
}
function updateRtgButtons(){
  var disp = state.editReturnToReview ? 'inline-block' : 'none';
  var label = '\u29C9 Return to grid';
  var fn = 'returnToGrid()';
  document.querySelectorAll('.rtg').forEach(function(b){
    b.style.display = disp;
    b.innerHTML = label;
    b.setAttribute('onclick', fn);
  });
}
function nextInEditQueue(){
  if (state.editReturnToReview && state.editQueue.length){
    var i = state.editQueue.shift();
    enterItem(i);
  } else {
    state.editReturnToReview = false;
    goReview();
  }
}

// ---- APPLY with calm fade in/out ----
function fadeSwap(el, text){
  el.style.transition = 'opacity .45s ease';
  el.style.opacity = '0';
  setTimeout(function(){ el.textContent = text; el.style.opacity = '1'; }, 450);
}

function applyAll(){
  // Final confirmation gate (with duplicate detection), unless this is
  // a quick re-apply coming back from the report detail edits.
  if (!state._applyConfirmed){
    var total = state.items.length;
    // Duplicate detection: same chosen game used by 2+ shortcuts.
    var byGame = {}; var dups = [];
    state.items.forEach(function(it){
      var pick = state.picks[it.index] || {game:1,cover:1};
      var sec = (it.sections && it.sections.length) ? (it.sections[pick.game-1] || it.sections[0]) : null;
      var key = sec ? (sec.gameId ? ('id:'+sec.gameId) : ('nm:'+(sec.gameName||'').toLowerCase())) : null;
      if (key){ (byGame[key] = byGame[key] || []).push(sec.gameName || it.name); }
    });
    Object.keys(byGame).forEach(function(k){ if (byGame[k].length > 1){ dups.push(byGame[k][0] + ' (x' + byGame[k].length + ')'); } });
    var msg = 'This will update ' + total + ' shortcut' + (total===1?'':'s') + ' with your chosen icons.';
    if (dups.length){ msg += ' Heads up: some shortcuts point to the same game, so they will get the same icon: ' + dups.join(', ') + '.'; }
    $('applyConfirmText').textContent = msg;
    show('step-confirm-apply');
    return;
  }
  state._applyConfirmed = false;
  setProgress(2);
  show('step-loading');
  $('loadFill').style.width = '6%';
  $('loadDetail').textContent = '';
  $('autoFeed').innerHTML = '';
  var picks = state.items.map(function(it){
    var pick = state.picks[it.index] || { game:1, cover:1 };
    var sec = (it.sections && it.sections.length) ? (it.sections[pick.game-1] || it.sections[0]) : null;
    var cover = sec ? (sec.covers[pick.cover-1] || sec.covers[0]) : null;
    return {
      index: it.index,
      url: cover ? cover.url : '',
      gameId: sec ? sec.gameId : 0,
      gameName: sec ? sec.gameName : it.name
    };
  });
  api('/api/apply-begin', { picks: picks }).then(function(res){
    if (!res.ok){ goReview(); alert(res.error || 'Apply failed.'); return; }
    var phases = [
      'Downloading your cover art...',
      'Building crisp, multi-size icons...',
      'Safely backing up your current icons...',
      'Placing the new icons on your shortcuts...',
      'Refreshing Windows so they show up...'
    ];
    var pi = 0, pct = 12, finished = false;
    var applyCount = (res && res.total) ? res.total : state.items.length;
    $('loadDetail').textContent = 'This usually takes ' + estimateSeconds(applyCount, 1.0) + '.';
    var cycle = function(){
      if (finished) return;
      fadeSwap($('loadingMsg'), phases[pi]);
      pi = (pi+1) % phases.length;
      pct = Math.min(92, pct+5);
      $('loadFill').style.width = pct + '%';
    };
    cycle();
    var timer = setInterval(cycle, 1400);   // livelier pace while work runs
    api('/api/apply-step', { i:0 }).then(function(r2){
      finished = true; clearInterval(timer);
      if (!r2.ok){ goReview(); alert(r2.error || 'Apply failed.'); return; }
      $('loadFill').style.width = '100%';
      fadeSwap($('loadingMsg'), 'Done! Your game shelf is ready.');
      setTimeout(function(){ renderReport(r2.report); }, 500);
    });
  });
}

function renderReport(r){
  state.report = r;
  setProgress(3);
  var g = $('reportGrid'); g.innerHTML = '';
  var stats = [
    ['Updated', r.updated, 'var(--good)', 'updated'],
    ['Matched', r.matched, 'var(--accent2)', 'matched'],
    ['Placeholder', r.placeholder, 'var(--warn)', 'placeholder'],
    ['Skipped', r.skipped, 'var(--muted)', 'skipped'],
    ['Failed', r.failed, 'var(--bad)', 'failed']
  ];
  stats.forEach(function(s){
    var d = document.createElement('div'); d.className='stat';
    d.innerHTML = '<div class="n" style="color:'+s[2]+'">'+s[1]+'</div><div class="l">'+s[0]+'</div>';
    g.appendChild(d);
  });
  show('step-report'); setNavFocus('reportBtns', 0);
  renderStats(r);
}

function renderStats(r){
  var box = $('statsBox');
  if (!box) return;
  var details = r.details || [];
  var total = r.total || details.length;
  var done = (r.updated || 0);
  var successRate = total ? Math.round(done/total*100) : 0;

  // Most common release decade among matched games (a fun stat).
  var years = {};
  // We do not have per-game years in details, so summarise by category instead.
  var parts = [];
  parts.push(statCard('Shortcuts processed', total));
  parts.push(statCard('Icons updated', done));
  parts.push(statCard('Success rate', successRate + '%'));
  parts.push(statCard('Placeholders made', r.placeholder || 0));
  box.innerHTML = '<div class="stats-title">This run at a glance</div><div class="stats-row">' + parts.join('') + '</div>';
}
function statCard(label, val){
  return '<div class="ministat"><div class="ministat-n">' + val + '</div><div class="ministat-l">' + label + '</div></div>';
}


// ---- nav focus (button rows) ----
var navState = { row:null, idx:0 };
function setNavFocus(rowId, idx){
  navState.row = rowId; navState.idx = idx;
  var btns = document.querySelectorAll('#'+rowId+' [data-nav]');
  if (btns.length){ btns[Math.min(idx,btns.length-1)].focus(); }
}
function moveNav(delta){
  if (!navState.row) return;
  var btns = document.querySelectorAll('#'+navState.row+' [data-nav]');
  if (!btns.length) return;
  navState.idx = (navState.idx + delta + btns.length) % btns.length;
  btns[navState.idx].focus();
}

// ---- tiles ----
function focusTiles(sel){
  var tiles = document.querySelectorAll(sel+' .tile');
  tiles.forEach(function(t,i){ t.classList.toggle('focus', i===state.focusIdx); });
  var f = tiles[state.focusIdx]; if (f) f.scrollIntoView({block:'nearest'});
}

// ---- keyboard ----
document.addEventListener('keydown', function(e){
  // Never interfere with OS/browser shortcuts: if any modifier is held
  // (Ctrl/Cmd/Alt) or the key is Tab, let the browser handle it.
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  if (e.key === 'Tab') return;

  // global single-key shortcuts (only when not typing in a field)
  if (!isTyping(e) && (e.key === 'f' || e.key === 'F')){ toggleFullscreen(); return; }
  if (!isTyping(e) && e.key === 'Backspace'){ e.preventDefault(); goBack(); return; }
  if (!isTyping(e) && (e.key === '+' || e.key === '=')){ e.preventDefault(); zoomIn(); return; }
  if (!isTyping(e) && (e.key === '-' || e.key === '_')){ e.preventDefault(); zoomOut(); return; }

  if (visible('step-home')){
    if (e.key === 'ArrowRight'){ state.homeFocus = Math.min(2, state.homeFocus+1); focusHome(); e.preventDefault(); }
    else if (e.key === 'ArrowLeft'){ state.homeFocus = Math.max(0, state.homeFocus-1); focusHome(); e.preventDefault(); }
    else if (e.key === 'Enter'){ document.querySelectorAll('.home-btn')[state.homeFocus].click(); }
    return;
  }
  if (visible('step-folder')){
    if (e.key === 'Enter' && document.activeElement === $('folderInput')){ tryTypedFolder(); }
    else if (e.key === 'Enter' && !$('scanBtn').classList.contains('hidden')){ startScan(); }
    return;
  }
  if (visible('step-confirm')){
    if (e.key === 'ArrowRight'){ moveNav(1); e.preventDefault(); }
    else if (e.key === 'ArrowLeft'){ moveNav(-1); e.preventDefault(); }
    else if (e.key === 'Enter'){ if (document.activeElement && document.activeElement.dataset.nav!==undefined){ document.activeElement.click(); } else { acceptMatch(); } }
    else if (e.key.toLowerCase() === 'c'){ showArtwork(); }
    else if (e.key.toLowerCase() === 'w'){ showOtherMatches(); }
    else if (e.key.toLowerCase() === 'a'){ chooseAllAuto(); }
    return;
  }
  if (visible('step-artwork') || visible('step-matches')){
    var sel = visible('step-artwork') ? '#artworkGrid' : '#matchesGrid';
    var gridEl = document.querySelector(sel);
    var tiles = document.querySelectorAll(sel+' .tile');
    if (!tiles.length) return;
    var cols = Math.max(1, Math.floor(gridEl.clientWidth/150));
    if (e.key === 'ArrowRight'){ state.focusIdx=Math.min(tiles.length-1,state.focusIdx+1); focusTiles(sel); e.preventDefault(); }
    else if (e.key === 'ArrowLeft'){ state.focusIdx=Math.max(0,state.focusIdx-1); focusTiles(sel); e.preventDefault(); }
    else if (e.key === 'ArrowDown'){ state.focusIdx=Math.min(tiles.length-1,state.focusIdx+cols); focusTiles(sel); e.preventDefault(); }
    else if (e.key === 'ArrowUp'){ state.focusIdx=Math.max(0,state.focusIdx-cols); focusTiles(sel); e.preventDefault(); }
    else if (e.key === 'Enter'){ e.preventDefault(); tiles[state.focusIdx].click(); }
    return;
  }
  if (visible('step-review')){
    if (e.key === 'ArrowRight'){ moveNav(1); e.preventDefault(); }
    else if (e.key === 'ArrowLeft'){ moveNav(-1); e.preventDefault(); }
    else if (e.key === 'Enter'){ if (document.activeElement && document.activeElement.dataset.nav!==undefined) document.activeElement.click(); else applyAll(); }
    return;
  }
  if (visible('step-report')){
    if (e.key === 'ArrowRight'){ moveNav(1); e.preventDefault(); }
    else if (e.key === 'ArrowLeft'){ moveNav(-1); e.preventDefault(); }
    else if (e.key === 'Enter'){ if (document.activeElement && document.activeElement.dataset.nav!==undefined) document.activeElement.click(); }
    return;
  }
});
function isTyping(e){ var el = document.activeElement; return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA'); }

// ---- back ----
function goBack(){
  if (visible('step-artwork') || visible('step-matches')){ renderConfirm(); return; }
  if (visible('step-confirm')){
    if (state.history.length){ state.pos = state.history.pop(); renderConfirm(); }
    else { goHome(); }
    return;
  }
  if (visible('step-review')){ enterItem(state.items.length-1); return; }
  if (visible('step-folder')){ goHome(); return; }
}

// boot
try { var z = parseFloat(localStorage.getItem('gis-zoom')); if (z >= 0.7 && z <= 1.7) state.zoom = z; } catch(e){}
try { state.gallery = (localStorage.getItem('gis-gallery') === '1'); } catch(e){}
applyZoom();
loadSavedTheme();
checkKey();
'@
}
