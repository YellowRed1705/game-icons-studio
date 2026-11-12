# ============================================================
#  WebApp.ps1 (v6.48) - Game Icons Studio browser UI
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
<title>Game Icons Studio v6.48</title>
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

  /* HOME: compact dashboard; all eight primary actions fit without page scrolling on desktop. */
  #step-home { padding:15px 22px; gap:9px; max-height:none; overflow:visible; }
  .home-hero { text-align:center; }
  .home-hero h2 { font-size:1.45rem; line-height:1.15; margin:0 0 3px; }
  .home-hero p { color:var(--muted); margin:0; font-size:.82rem; line-height:1.25; }
  .home-grid {
    display:grid; grid-template-columns:repeat(4,minmax(0,1fr));
    gap:10px; width:100%; margin-top:0; align-items:stretch;
  }
  .home-btn {
    width:auto; min-width:0; min-height:0; height:clamp(124px,17vh,146px);
    background:var(--panel2); border:1px solid var(--line); border-radius:13px;
    padding:10px 12px; cursor:pointer; display:flex; flex-direction:column;
    align-items:center; justify-content:center; gap:5px; text-align:center;
    transition:transform .12s,border-color .12s; color:var(--text); overflow:hidden;
  }
  .home-btn:hover { transform:translateY(-2px); border-color:var(--accent); }
  .home-btn.focus { border-color:var(--accent2); transform:translateY(-2px); }
  .home-btn .ic { width:36px; height:36px; flex:0 0 36px; }
  .home-btn .t { font-size:.9rem; line-height:1.15; font-weight:700; }
  .home-btn .d {
    max-width:100%; font-size:.72rem; color:var(--muted); line-height:1.22;
    display:-webkit-box; -webkit-box-orient:vertical; -webkit-line-clamp:3;
    line-clamp:3; overflow:hidden;
  }
  .home-tools { display:flex; gap:8px; flex-wrap:wrap; justify-content:center; margin-top:1px; }
  .home-tools .tool-btn { font-size:.76rem; padding:6px 11px; }
  #step-home > .kbd-hint { font-size:.68rem; line-height:1.1; }
  @media (max-width:780px) {
    #step-home { padding:14px; gap:10px; }
    .home-grid { grid-template-columns:repeat(2,minmax(0,1fr)); gap:9px; }
    .home-btn { height:auto; min-height:128px; padding:12px 10px; }
    .home-btn .ic { width:34px; height:34px; flex-basis:34px; }
    .home-btn .d { -webkit-line-clamp:3; line-clamp:3; }
    .home-tools { gap:6px; }
    .home-tools .tool-btn { font-size:.72rem; padding:6px 8px; }
  }
  @media (max-height:620px) and (min-width:781px) {
    #step-home { padding:9px 16px; gap:6px; }
    .home-grid { gap:7px; }
    .home-btn { height:112px; padding:7px 9px; gap:3px; }
    .home-btn .ic { width:28px; height:28px; flex-basis:28px; }
    .home-btn .t { font-size:.82rem; }
    .home-btn .d { font-size:.66rem; -webkit-line-clamp:2; line-clamp:2; }
    .home-tools .tool-btn { padding:4px 9px; }
  }

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
  .tile img.cover-loading { opacity:.58; }
  .tile img.cover-ready { opacity:1; transition:opacity .14s ease; }
  .tile img.cover-error { opacity:.28; }
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
  .phase-text { min-height:1.4em; font-size:1.02rem; color:var(--text); font-weight:650; }
  .progress-stats { width:min(620px,76vw); display:flex; align-items:center; justify-content:space-between; gap:16px; margin-top:-5px; }
  .progress-percent { font-size:1rem; min-width:68px; font-weight:800; color:var(--accent2); font-variant-numeric:tabular-nums; }
  .progress-counter { min-width:0; text-align:right; font-size:.84rem; color:var(--text); font-variant-numeric:tabular-nums; overflow-wrap:anywhere; }
  .progress-detail { width:min(720px,82vw); min-height:1.4em; text-align:center; font-size:.92rem; }
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

  /* Keep restore-point dropdown readable in native Chromium/Windows menus.
     Native option popups do not reliably inherit translucent glass colors. */
  #backupRetention {
    color:#eef3ff !important;
    background-color:#172033 !important;
    border-color:var(--line);
    color-scheme:dark;
  }
  #backupRetention option,
  #backupRetention optgroup {
    color:#eef3ff !important;
    background-color:#172033 !important;
  }
  #backupRetention option:checked {
    color:#ffffff !important;
    background-color:#2563eb !important;
  }
  [data-theme="light"] #backupRetention,
  [data-theme="modern-light"] #backupRetention,
  [data-theme="minimal"] #backupRetention {
    color:#1a2230 !important;
    background-color:#ffffff !important;
    color-scheme:light;
  }
  [data-theme="light"] #backupRetention option,
  [data-theme="light"] #backupRetention optgroup,
  [data-theme="modern-light"] #backupRetention option,
  [data-theme="modern-light"] #backupRetention optgroup,
  [data-theme="minimal"] #backupRetention option,
  [data-theme="minimal"] #backupRetention optgroup {
    color:#1a2230 !important;
    background-color:#ffffff !important;
  }
  [data-theme="light"] #backupRetention option:checked,
  [data-theme="modern-light"] #backupRetention option:checked,
  [data-theme="minimal"] #backupRetention option:checked {
    color:#ffffff !important;
    background-color:#2563eb !important;
  }
  .ghost.btn-google { border-color:#38bdf8; color:#38bdf8; font-weight:600; }
  .ghost.btn-google:hover { background:linear-gradient(135deg,#0284c7,#2563eb); color:#fff; box-shadow:0 0 0 1px rgba(56,189,248,.5), 0 8px 22px rgba(56,189,248,.4); }
  .btn-yandex { border:1px solid #ffcc00 !important; color:var(--text); background:linear-gradient(135deg,rgba(255,204,0,.12),rgba(255,204,0,.04)); }
  .btn-yandex:hover { background:#ffcc00; color:#171717; box-shadow:0 8px 22px rgba(255,204,0,.22); }
  #step-custom { gap:10px; }
  #step-custom .search-tip { margin:0; }
  #step-custom #customImageSearchButtons { width:100%; max-width:760px; margin:0 auto; gap:12px; }
  #step-custom #customImageSearchButtons button { flex:1 1 220px; min-height:48px; margin:0; }
  #step-custom #googleImagesBtn { background:linear-gradient(135deg,#2563eb,#0ea5e9); color:#fff; border:1px solid rgba(96,165,250,.6); }
  #step-custom #yandexImagesBtn { background:linear-gradient(135deg,#ffcc00,#f59e0b); color:#171717; border:1px solid rgba(255,204,0,.8); font-weight:700; }
  #step-custom #googleImagesBtn:hover, #step-custom #yandexImagesBtn:hover { filter:brightness(1.08); transform:translateY(-1px); }
  #step-custom .custom-layout { display:grid; grid-template-columns:minmax(280px,1fr) 240px; gap:14px; align-items:stretch; }
  #step-custom #customDropZone { grid-column:1; grid-row:1; min-height:250px; height:100%; }
  #step-custom #customPreviewDropZone { grid-column:2; grid-row:1; }
  #step-custom #customCropEditor { display:none; grid-column:1 / -1; grid-row:2; }
  #step-custom #customCropEditor.visible { display:block; }
  #step-custom .drop-zone.drop-ready {
    border-color:var(--good); background:linear-gradient(135deg,rgba(52,211,153,.15),rgba(56,189,248,.08));
    box-shadow:0 0 0 2px rgba(52,211,153,.16),0 12px 32px rgba(0,0,0,.18);
  }
  #step-custom .drop-zone.drop-ready::before {
    content:'DROP AREA READY'; color:var(--good); font-size:.7rem; font-weight:800;
    letter-spacing:.12em; margin-bottom:2px;
  }
  #step-custom .preview-box { min-width:0; }
  @media(max-width:760px) {
    #step-custom .custom-layout { grid-template-columns:1fr; }
    #step-custom #customDropZone { grid-column:1; grid-row:1; }
    #step-custom #customPreviewDropZone { grid-column:1; grid-row:2; }
    #step-custom #customCropEditor { grid-column:1; grid-row:3; }
    #step-custom .preview-box { flex-basis:auto; }
    #step-custom #customImageSearchButtons { flex-wrap:wrap; }
  }
  @media(max-height:850px) and (min-width:761px) {
    #step-custom { padding:14px 20px; gap:7px; max-height:calc(100vh - 112px); overflow-y:auto; }
    #step-custom h2 { font-size:1.25rem; }
    #step-custom .search-tip { font-size:.78rem; line-height:1.25; }
    #step-custom .custom-layout { gap:10px; }
    #step-custom .drop-zone { min-height:190px; padding:12px; gap:7px; }
    #step-custom #customCanvas { width:140px; height:140px; }
    #step-custom .preview-box { padding:10px; gap:6px; }
    #step-custom .url-row { gap:6px; }
    #step-custom #customStatusMsg { min-height:.8em !important; }
  }
  .crop-editor { width:100%; flex:1 1 100%; order:3; padding:14px; border:1px solid var(--line); border-radius:14px; background:var(--panel); text-align:left; }
  .crop-editor-head { display:flex; gap:12px; align-items:center; justify-content:space-between; flex-wrap:wrap; margin-bottom:9px; }
  .crop-editor-title { font-weight:800; font-size:.9rem; }
  .crop-editor-tools { display:flex; gap:6px; align-items:center; }
  .crop-editor-tools button { min-width:34px; padding:6px 10px; }
  #customZoomLabel { min-width:48px; text-align:center; color:var(--muted); font-size:.78rem; font-variant-numeric:tabular-nums; }
  .crop-stage { width:100%; max-width:960px; margin:0 auto; border:1px solid var(--line); border-radius:10px; overflow:hidden; background:#0b1019; }
  #customSourceCanvas { display:block; width:100%; height:auto; aspect-ratio:16/9; touch-action:none; cursor:crosshair; }
  .crop-editor-hint { color:var(--muted); font-size:.75rem; line-height:1.4; margin-top:8px; text-align:center; }
  .online-candidate { min-width:0; border:1px solid var(--line); border-radius:12px; padding:7px; background:var(--panel2); cursor:pointer; color:var(--text); text-align:center; }
  .online-candidate:hover,.online-candidate:focus { border-color:var(--accent); transform:translateY(-1px); }
  .online-candidate img { width:100%; aspect-ratio:1; object-fit:contain; border-radius:8px; background:rgba(127,127,127,.08); display:block; }
  .online-candidate-title { font-size:.74rem; line-height:1.3; margin-top:6px; overflow-wrap:anywhere; color:var(--text); }
  .online-candidate-meta { color:var(--muted); font-size:.68rem; margin-top:4px; }
  .online-candidate-use { margin-top:7px; width:100%; border:1px solid var(--accent); border-radius:8px; padding:5px 6px; background:transparent; color:var(--text); cursor:pointer; font-size:.72rem; }
  .online-candidate-use:hover { background:var(--accent); color:white; }
  .search-kind-row { gap:8px; margin:4px 0 2px; }
  .search-kind-btn { min-width:150px; }
  .search-kind-btn.active { border-color:var(--accent2); background:var(--accent); color:#fff; }
  .search-tip { max-width:760px; line-height:1.55; }
  .custom-layout { display:flex; gap:24px; align-items:stretch; justify-content:center; flex-wrap:wrap; width:100%; }
  .drop-zone {
    flex:1 1 320px; min-height:220px; border:2px dashed var(--accent); border-radius:16px;
    background:var(--panel2); display:flex; flex-direction:column; align-items:center;
    justify-content:center; gap:10px; padding:20px; cursor:pointer; text-align:center;
    transition:all .15s ease;
  }
  .drop-zone:hover, .drop-zone.dragover {
    border-color:var(--good); background:rgba(52,211,153,.08); transform:scale(1.01);
  }
  .preview-box {
    flex:0 0 240px; display:flex; flex-direction:column; align-items:center; gap:10px;
    background:var(--panel2); border:1px solid var(--line); border-radius:16px; padding:16px;
  }
  #customCanvas {
    width:180px; height:180px; border-radius:24px; border:2px solid var(--accent);
    background:repeating-conic-gradient(#1a1e27 0% 25%, #141821 0% 50%) 50% / 16px 16px;
  }
  .url-row { display:flex; gap:8px; width:100%; max-width:680px; justify-content:center; flex-wrap:wrap; }
  .lang-switch {
    display:inline-flex; align-items:center; justify-content:center;
    padding:0; border:0; border-radius:10px; background:transparent;
    box-shadow:none; flex:0 0 auto;
  }
  .lang-option {
    display:none; align-items:center; justify-content:center;
    width:38px; min-width:38px; height:36px; padding:0;
    border:1px solid var(--line); border-radius:10px;
    background:var(--panel); color:var(--text); font:inherit; cursor:pointer;
    transition:background .16s ease,border-color .16s ease,transform .16s ease;
  }
  .lang-option:not(.active) { display:none !important; }
  .lang-option.active { display:inline-flex; background:var(--panel); border-color:var(--accent2); }
  .lang-option:hover { background:var(--line); transform:translateY(-1px); }
  .lang-option:focus-visible { outline:2px solid var(--accent2); outline-offset:2px; }
  .lang-option span { display:none; }
  #languageSwitcher { direction:ltr; unicode-bidi:isolate; flex:0 0 auto; }
  #languageSwitcher .lang-flag { pointer-events:none; }
  .lang-flag { display:block; width:24px; height:16px; flex:0 0 24px; border-radius:3px; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,.28); }
  @media(max-width:760px) {
    .lang-option { width:36px; min-width:36px; height:34px; }
    .lang-flag { width:22px; height:15px; flex-basis:22px; }
  }
  .game-match-search { display:flex; flex-direction:column; gap:9px; margin:14px 0 18px; padding:12px; border:1px solid var(--line); border-radius:12px; background:var(--panel); }
  .game-match-search-row { display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
  .game-match-search-row .input-path { flex:1 1 280px; max-width:none; margin:0; }
  .game-match-search-actions { display:flex; gap:8px; flex-wrap:wrap; align-items:center; }
  #gameSearchStatus { color:var(--muted); font-size:.82rem; min-height:1.2em; }
  .review-change-game { display:block; margin:8px auto 0; padding:5px 9px; border:1px solid var(--line); border-radius:8px; background:var(--panel); color:var(--accent2); font:inherit; font-size:.72rem; font-weight:700; cursor:pointer; }
  .review-change-game:hover { border-color:var(--accent2); background:var(--line); }
  .hidden { display:none !important; }
  html[dir="rtl"] { direction: rtl; font-family: 'Segoe UI', Tahoma, Arial, sans-serif; }
  html[dir="rtl"] .iconbtn, html[dir="rtl"] .theme-btn, html[dir="rtl"] .ghost { margin-left: 0; margin-right: 8px; }
  html[dir="rtl"] .logo-img { margin-right: 0; margin-left: 10px; }
  html[dir="rtl"] .brand h1, html[dir="rtl"] .brand p { text-align: right; }
  html[dir="rtl"] .footer-nav { flex-direction: row-reverse; }
  html[dir="rtl"] .kbd-hint { direction: ltr; }
</style>
</head>
<body>
<header>
  <img class="logo-img" src="/assets/brand.png" alt="Game Icons Studio">
  <div class="brand">
    <h1>Game Icons Studio</h1>
    <p>Game and app icons, with safe restore history.</p>
  </div>
  <div class="spacer"></div>
  <div class="lang-switch" id="languageSwitcher" role="group" aria-label="Language">
    <button type="button" class="lang-option active" data-lang="en" onclick="toggleLang()" title="English"><svg class="lang-flag" viewBox="0 0 60 30" role="img" aria-label="United Kingdom flag"><clipPath id="uk-clip"><path d="M0 0h60v30H0z"/></clipPath><g clip-path="url(#uk-clip)"><path fill="#012169" d="M0 0h60v30H0z"/><path stroke="#fff" stroke-width="6" d="M0 0l60 30M60 0L0 30"/><path stroke="#C8102E" stroke-width="2.5" d="M0 0l60 30M60 0L0 30"/><path stroke="#fff" stroke-width="10" d="M30 0v30M0 15h60"/><path stroke="#C8102E" stroke-width="6" d="M30 0v30M0 15h60"/></g></svg><span>EN</span></button>
    <button type="button" class="lang-option" data-lang="tr" onclick="toggleLang()" title="Türkçe"><svg class="lang-flag" viewBox="0 0 60 30" role="img" aria-label="Turkish flag"><rect width="60" height="30" fill="#E30A17"/><circle cx="25" cy="15" r="8" fill="#fff"/><circle cx="28" cy="15" r="6.4" fill="#E30A17"/><path fill="#fff" d="M39 9.8l1.5 3.7 4 .2-3.1 2.4 1.1 3.8-3.5-2.1-3.4 2.1 1.1-3.8-3.1-2.4 4-.2z"/></svg><span>TR</span></button>
    <button type="button" class="lang-option" data-lang="ar" onclick="toggleLang()" title="العربية"><svg class="lang-flag" viewBox="0 0 60 30" role="img" aria-label="Saudi Arabian flag"><rect width="60" height="30" rx="2" fill="#006C35"/><text x="30" y="12.2" text-anchor="middle" direction="rtl" font-family="Tahoma,Arial,sans-serif" font-size="5.1" font-weight="700" fill="#fff">لا إله إلا الله محمد رسول الله</text><path d="M14 19h31" stroke="#fff" stroke-width="1.8" stroke-linecap="round"/><path d="M44.5 17.8l2 1.2-2 1.2" fill="none" stroke="#fff" stroke-width="1.1" stroke-linecap="round" stroke-linejoin="round"/></svg><span>AR</span></button>
  </div>
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
    <p class="sub" style="max-width:620px;">Game Icons Studio finds game covers through <b>SteamGridDB</b>. A free API key is needed for automatic game matching, but not for the Program &amp; App Icons workflow.</p>

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

    <input class="input-path" id="keyInput" type="password" placeholder="Paste your API key here" autocomplete="off" spellcheck="false" />
    <p class="sub" id="keyStorageNotice" style="max-width:620px;">Your API Key is stored only in this browser's local storage. It is never written to settings.json or GitHub.</p>
    <div class="btn-row">
      <button class="big-btn btn-good" onclick="pasteKey()">&#128203; Paste &amp; continue</button>
      <button class="ghost" onclick="saveKey()">Continue</button>
    </div>
    <div id="keyMsg" class="sub"></div>
    <div class="btn-row" style="margin-top:8px;">
      <button class="ghost" onclick="continueWithoutKey()">Continue with Program &amp; App Icons (no API key)</button>
    </div>
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
      <button class="ghost btn-google" data-nav onclick="openGoogleCustom()">&#128269; Google / Custom Cover</button>
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
      <button class="home-btn home-btn-primary" data-home="0" onclick="startGameFilesFolder()">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><path d="M3 6.5A2.5 2.5 0 0 1 5.5 4H10l2 2h6.5A2.5 2.5 0 0 1 21 8.5v9a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5z"/><path d="M8 13h8M12 9v8"/></svg>
        <div class="t">Game Library Folder</div>
        <div class="d">Recommended. Scan .lnk, .url, Steam/Epic/Ubisoft launchers, EXE files and emulator ROMs. Create working Windows shortcuts and match game art.</div>
      </button>
      <button class="home-btn" data-home="1" onclick="startFolderMode('all')">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/><path d="M12 11v6"/><path d="M9 14l3 3 3-3"/></svg>
        <div class="t">All Sub-Folders</div>
        <div class="d">Set custom icons for all sub-folders in a parent directory.</div>
      </button>
      <button class="home-btn" data-home="2" onclick="startFolderMode('single')">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
        <div class="t">Specific Folder</div>
        <div class="d">Customize the icon for one specifically chosen folder.</div>
      </button>
      <button class="home-btn" data-home="3" onclick="startChangeIcons()">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>
        <div class="t">Specific Shortcuts</div>
        <div class="d">Pick just the shortcuts you want to redo and choose new covers.</div>
      </button>
      <button class="home-btn" data-home="4" onclick="repairIconCache()">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><path d="M14.7 6.3a4 4 0 0 0-5.4 5.4l-5.6 5.6a1.5 1.5 0 0 0 2.1 2.1l5.6-5.6a4 4 0 0 0 5.4-5.4l-2.4 2.4-2.1-2.1Z"/></svg>
        <div class="t">Repair Broken Icons</div>
        <div class="d">Scan a game folder, repair missing .ico references from saved artwork, and refresh the Windows icon cache.</div>
      </button>
      <button class="home-btn" data-home="5" onclick="startFullScan(true)">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><rect x="3" y="3" width="18" height="18" rx="4"/><path d="M8 8h8v8H8z"/><path d="M12 1v4M12 19v4M1 12h4M19 12h4"/></svg>
        <div class="t">Program &amp; App Icons</div>
        <div class="d">Search Google or Yandex Images for app icons and apply them to shortcuts.</div>
      </button>
      <button class="home-btn" data-home="6" onclick="startChangeIcons(true)">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><path d="M4 4h16v16H4z"/><path d="M8 8h3v3H8zM13 8h3M13 11h3M8 14h8M8 17h5"/></svg>
        <div class="t">Any Files &amp; Scripts</div>
        <div class="d">Choose .exe, .bat, .cmd, .ps1 and other files. Custom icon shortcuts are created beside regular files.</div>
      </button>
      <button class="home-btn" data-home="7" onclick="startFullScan()">
        <svg class="ic" viewBox="0 0 24 24" fill="none" stroke="var(--accent2)" stroke-width="1.6"><rect x="3" y="4" width="18" height="14" rx="2"/><path d="M3 9h18"/><path d="M8 14h2M12 14h4"/></svg>
        <div class="t">Shortcuts Only</div>
        <div class="d">Legacy mode. Scan only existing Windows .lnk shortcuts in a folder.</div>
      </button>
    </div>
    <div class="home-tools">
      <button class="ghost tool-btn" onclick="quickReapply()" title="Re-apply your last saved choices">&#8635; Quick re-apply</button>
      <button class="ghost tool-btn" onclick="undoLastIconChange()" title="Undo the most recent icon change">&#8617; Undo Last Change</button>
      <button class="ghost tool-btn" onclick="openHistory()" title="See what you changed and when">&#128340; History</button>
      <button class="ghost tool-btn" id="backupHomeBtn" onclick="openBackups()" title="Browse all restore points">&#8635; Undo / Restore</button>
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

  <!-- BACKUP / RESTORE HISTORY -->
  <div class="card center-col hidden" id="step-backups">
    <h2 id="backupTitle">Undo &amp; Restore</h2>
    <p class="sub" id="backupSubtitle" style="max-width:720px;">Restore previous shortcut and folder icon states from saved restore points. Restore points are created automatically before applying changes.</p>
    <div class="url-row" style="max-width:720px;align-items:center;">
      <label for="backupRetention" id="backupRetentionLabel">Keep restore points:</label>
      <select class="input-path" id="backupRetention" style="max-width:280px;" onchange="saveBackupRetention()">
        <option value="10">Last 10 versions</option>
        <option value="25">Last 25 versions</option>
        <option value="50">Last 50 versions</option>
        <option value="100">Last 100 versions</option>
        <option value="0">Unlimited (uses more disk space)</option>
      </select>
      <button class="ghost" onclick="openBackups()" id="backupRefreshBtn">Refresh</button>
    </div>
    <p class="sub" id="backupSettingStatus" style="min-height:1.2em;"></p>
    <div class="history-list" id="backupList" style="width:min(900px,100%);"></div>
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
        <p>Game Icons Studio turns generic icons on game and program shortcuts into polished icons. Game covers can be matched through SteamGridDB; app icons can be found through Google Images or Yandex Images, then previewed and applied locally.</p>
      </div>

      <div class="about-card">
        <div class="about-h">&#128268; Where the art comes from</div>
        <p>Game covers are matched through <b>SteamGridDB</b> (steamgriddb.com). For regular applications, use <b>Program &amp; App Icons</b> to search Google Images or Yandex Images. Drag the image into the app or copy/paste it; the app processes it locally. The SteamGridDB API key is only needed for game matching.</p>
      </div>

      <div class="about-card">
        <div class="about-h">&#9889; How it works (3 steps)</div>
        <p><b>1. Choose a folder</b> of game shortcuts (.lnk). The app scans them and matches each to a game.<br>
        <b>2. Review</b> the covers it picked. Keep the ones you like, change the ones you do not.<br>
        <b>3. Apply.</b> The app safely backs up your old icons, then sets the new ones and refreshes Windows.</p>
      </div>

      <div class="about-card">
        <div class="about-h">&#129513; What each button does</div>
        <p><b>Shortcuts Folder</b> &mdash; match game covers for shortcuts in a folder.<br>
        <b>Program &amp; App Icons</b> &mdash; search for application icons without SteamGridDB matching.<br>
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
    <h2 id="folderTitle">Choose your games folder</h2>
    <p class="sub" id="folderSubtitle">Select the folder that holds your game shortcuts (.lnk), or paste its path.</p>
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
      <div class="bigbar" role="progressbar" aria-label="Operation progress" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" id="loadBar"><div class="bigbar-fill" id="loadFill"></div></div>
      <div class="progress-stats">
        <span id="loadPercent" class="progress-percent">0%</span>
        <span id="loadCounter" class="progress-counter">Waiting for live progress…</span>
      </div>
      <div id="loadDetail" class="sub progress-detail"></div>
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
      <button class="ghost btn-google" data-nav onclick="openGoogleCustom()">&#128269; Google / Custom Cover</button>
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
    <div class="game-match-search" id="gameSearchPanel">
      <div class="game-match-search-row">
        <input class="input-path" id="gameSearchInput" type="text" maxlength="120" placeholder="Search another game by title…" onkeydown="if(event.key==='Enter'){event.preventDefault();searchGameCandidates();}" />
        <button class="big-btn btn-go" id="gameSearchButton" type="button" onclick="searchGameCandidates()">Search SteamGridDB</button>
      </div>
      <div class="game-match-search-actions">
        <button class="ghost" id="useCustomGameTitleButton" type="button" onclick="useCustomGameTitle()">Use a custom title + choose cover</button>
        <span id="gameSearchStatus" aria-live="polite">Select an existing match, search SteamGridDB, or enter a custom title.</span>
      </div>
    </div>
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
  <!-- CUSTOM ICON STUDIO: works for both games and regular application shortcuts -->
  <div class="card center-col hidden" id="step-custom">
    <h2 id="customTitle">Custom Icon Studio</h2>
    <p class="sub" id="customShortcutTitle"></p>

    <div class="btn-row search-kind-row" id="customSearchKindButtons">
      <button class="ghost vt-btn search-kind-btn" id="customKindGame" onclick="setCustomSearchKind('game')">Game cover</button>
      <button class="ghost vt-btn search-kind-btn active" id="customKindProgram" onclick="setCustomSearchKind('program')">Program / App icon</button>
    </div>

    <div class="btn-row" id="customImageSearchButtons">
      <button class="big-btn btn-go" id="googleImagesBtn" onclick="openGoogleSearch()">&#128269; Google Images</button>
      <button class="big-btn btn-yandex" id="yandexImagesBtn" onclick="openYandexSearch()">&#128269; Yandex Images</button>
      <button class="ghost" id="chooseLocalImageBtn" onclick="triggerCustomFile()">&#128193; Choose Local Image</button>
    </div>
    <div class="sub" id="onlineSearchStatus" aria-live="polite" style="min-height:1.2em;max-width:760px;">Choose Google or Yandex Images, then drag an image into the large drop area below.</div>
    <p class="sub search-tip" id="customSearchHint">Search for a high-resolution result, then drag the image directly onto the drop area or icon preview. You can also right-click an image, choose Copy image, and press Ctrl+V.</p>

    <div class="custom-layout">
      <div class="drop-zone" id="customDropZone" onclick="triggerCustomFile()">
        <div style="font-size:2.2rem;">&#128229;</div>
        <div style="font-weight:700;font-size:1.02rem;">Drag &amp; Drop an image here, or press <kbd style="background:var(--panel);padding:2px 7px;border-radius:6px;border:1px solid var(--line);">Ctrl+V</kbd></div>
        <div class="sub" style="margin:0;max-width:340px;">Drag an image from Google Images or Yandex Images directly here, right-click it and choose <b>Copy image</b> then press <b>Ctrl+V</b>, or click to browse your PC.</div>
        <input type="file" id="customFileInput" accept="image/*" style="display:none" onchange="handleCustomFileSelect(event)" />
      </div>

      <div class="crop-editor" id="customCropEditor">
        <div class="crop-editor-head">
          <div class="crop-editor-title" id="customCropTitle">Select the area for your icon</div>
          <div class="crop-editor-tools">
            <button class="ghost" type="button" onclick="zoomCustomCrop(-1)" title="Zoom out">−</button>
            <span id="customZoomLabel">100%</span>
            <button class="ghost" type="button" onclick="zoomCustomCrop(1)" title="Zoom in">+</button>
            <button class="ghost" type="button" onclick="resetCustomCrop()" id="customCropResetBtn">Reset</button>
          </div>
        </div>
        <div class="crop-stage">
          <canvas id="customSourceCanvas" width="960" height="540" aria-label="Drag to select a square crop area"></canvas>
        </div>
        <div class="crop-editor-hint" id="customCropHint">Drag outside the current square to draw a new selection. Drag inside to move it. Zoom in to select a smaller detail.</div>
      </div>

      <div class="preview-box" id="customPreviewDropZone" title="You can also drop an image directly onto this preview">
        <div style="font-size:.82rem;color:var(--muted);font-weight:600;">ICON PREVIEW (1:1)</div>
        <canvas id="customCanvas" width="512" height="512" title="Drop an image here to preview it"></canvas>
        <div class="view-toggle" style="margin:0;">
          <button class="ghost vt-btn active" id="fitCrop" onclick="setCustomFitMode('crop')" title="Center crop to square">Crop 1:1</button>
          <button class="ghost vt-btn" id="fitContain" onclick="setCustomFitMode('contain')" title="Fit whole image with transparent padding">Fit</button>
          <button class="ghost vt-btn" id="fitStretch" onclick="setCustomFitMode('stretch')" title="Stretch to square">Stretch</button>
        </div>
      </div>
    </div>

    <div class="url-row">
      <input class="input-path" id="customUrlInput" placeholder="Paste a direct image URL and press Enter..." style="flex:1;min-width:260px;" onkeydown="if(event.key==='Enter') loadCustomUrlInput()" />
      <button class="ghost g-good" onclick="loadCustomUrlInput()">Load URL</button>
    </div>

    <div id="customStatusMsg" class="sub" style="min-height:1.2em;color:var(--accent2);"></div>

    <div class="btn-row">
      <button class="big-btn btn-good" id="customApplyBtn" disabled onclick="applyCustomCover()">&#10003; Apply this icon</button>
      <button class="ghost" id="customSkipBtn" onclick="cancelCustomIcon()">&larr; Cancel / Skip</button>
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
var i18n = {
  ar: {
    langBtn: "🌐 English",
    homeSubtitle: "اعثر على أغلفة الألعاب وأيقونات التطبيقات وطوّر اختصاراتك.",
    btnShortcuts: "مجلد مكتبة الألعاب",
    descShortcuts: "موصى به. افحص ملفات .lnk و.url وروابط Steam وEpic وUbisoft وملفات EXE وROM، وأنشئ اختصارات Windows قابلة للتشغيل.",
    btnShortcutsOnly: "الاختصارات فقط",
    descShortcutsOnly: "الوضع القديم: افحص اختصارات Windows القياسية .lnk فقط.",
    btnAllFolders: "جميع المجلدات الفرعية",
    descAllFolders: "فحص جميع المجلدات الفرعية للألعاب داخل مسار رئيسي وتخصيص أيقوناتها.",
    btnSingleFolder: "مجلد محدد",
    descSingleFolder: "اختيار مجلد لعبة واحد محدد لتخصيص أيقونته.",
    btnSpecific: "اختصارات محددة",
    descSpecific: "اختيار ملفات اختصارات محددة لتغيير أيقوناتها.",
    btnRepair: "إصلاح الأيقونات التالفة",
    descRepair: "افحص مجلد الألعاب وأصلح مراجع ICO المفقودة من الصور المحفوظة ثم حدّث ذاكرة أيقونات ويندوز.",
    btnUndoLast: "التراجع عن آخر تغيير",
    btnProgramIcons: "أيقونات البرامج والتطبيقات",
    descProgramIcons: "ابحث عن أيقونات التطبيقات في صور جوجل أو ياندكس وطبّقها على الاختصارات.",
    btnAnyFiles: "أي ملفات وسكربتات",
    descAnyFiles: "اختر ملفات EXE وBAT وCMD وPS1 وغيرها. يتم إنشاء اختصار منفصل للأيقونات المخصصة.",
    btnGameFiles: "مجلد ملفات الألعاب",
    descGameFiles: "افحص مجلد اللعبة بحثاً عن ملفات EXE والاختصارات، وأنشئ اختصارات Windows قابلة للتخصيص.",
    programFolderTitle: "اختر مجلد اختصارات البرامج",
    programFolderSub: "اختر المجلد الذي يحتوي على اختصارات التطبيقات والبرامج، أو الصق مساره.",
    programScanBtn: "فحص الاختصارات واختيار الأيقونات ←",
    yandexSearchBtn: "افتح صور ياندكس 🔍",
    customTitle: "استوديو الأيقونات المخصصة",
    kindGame: "غلاف لعبة",
    kindProgram: "أيقونة برنامج / تطبيق",
    customSearchHint: "ابحث عن صورة عالية الدقة، ثم اسحبها مباشرة إلى منطقة الإسقاط أو معاينة الأيقونة. يمكنك أيضاً نسخ الصورة ولصقها باستخدام Ctrl+V.",
    customApplyBtn: "تطبيق هذه الأيقونة",
    customSkipBtn: "تخطي هذا التطبيق",
    chooseLocalImage: "اختر صورة من الجهاز",
    btnQuick: "↻ إعادة تطبيق سريع",
    btnHistory: "🕒 السجل",
    btnUndo: "↶ تراجع / استعادة",
    backupTitle: "التراجع واستعادة الأيقونات",
    backupSubtitle: "استعد حالة الأيقونات السابقة من نقاط الاستعادة المحفوظة. يتم إنشاء نقطة قبل تطبيق التغييرات.",
    backupRetentionLabel: "الاحتفاظ بنقاط الاستعادة:",
    backupEmpty: "لا توجد نقاط استعادة بعد. طبّق الأيقونات مرة واحدة لإنشاء أول نسخة احتياطية.",
    backupRestore: "استعادة هذه النسخة",
    backupRestoreConfirm: "ستتم استعادة {0} عنصرًا إلى حالته السابقة. قد يؤدي ذلك إلى استبدال تغييرات أحدث على هذه العناصر. هل تريد المتابعة؟",
    backupRestoreDone: "اكتملت الاستعادة.",
    backupRestoreError: "تعذرت استعادة نقطة الاستعادة.",
    backupSaved: "تم حفظ إعداد سجل الاستعادة.",
    folderTitle: "اختر مجلد الألعاب",
    folderSub: "اختر المجلد الذي يحتوي على ألعابك، أو الصق المسار هنا.",
    scanBtn: "فحص المجلد ←",
    backBtn: "→ رجوع",
    stepFolder: "المجلد", stepMatch: "المطابقة والأغلفة", stepReview: "المراجعة", stepDone: "اكتمل",
    confirmTitle: "هل تعجبك هذه الأيقونة؟",
    confirmAutoTitle: "لست متأكداً من هذه اللعبة - هل تبدو صحيحة؟",
    shortcutProgress: "العنصر {0} من {1}:  {2}",
    releasedYear: "إصدار {0}",
    highestConfidence: "أعلى نسبة تطابق مع أفضل غلاف متاح.",
    whichGame: 'ما هي اللعبة "{0}"؟',
    btnLooksGood: "✓ تبدو ممتازة",
    btnDiffCover: "اختر غلافاً مختلفاً",
    btnWrongGame: "اللعبة خاطئة",
    btnAutoAll: "⚡ اختيار جميع الألعاب والأغلفة تلقائياً",
    btnReturnGrid: "⮩ العودة للشبكة",
    titleMatches: "اختر اللعبة الصحيحة",
    titleArtwork: "اختر الغلاف",
    titleReview: "اختر الأيقونات التي لا تعجبك لتغييرها",
    subReview: "انقر على أي أيقونة لا تعجبك (سيتم تظليلها)، ثم اضغط على 'تغيير هذه الأيقونات'. إذا كانت جميعها ممتازة، اضغط على إنهاء.",
    btnChangeSel: "تغيير هذه الأيقونات",
    btnFinishApply: "إنهاء! (تطبيق التغييرات)",
    btnStartOver: "البدء من جديد",
    reportTitle: "تم الانتهاء",
    reportSub: "هذا ملخص للعملية. يمكنك الإنهاء الآن، أو العودة لشبكة المراجعة لتعديل أي أيقونة.",
    statUpdated: "تم التحديث", statMatched: "تمت المطابقة", statPlaceholder: "أغلفة افتراضية", statSkipped: "تم التخطي", statFailed: "فشل",
    runAtGlance: "نظرة سريعة على العملية",
    miniProcessed: "عناصر تمت معالجتها", miniUpdated: "أيقونات تم تحديثها", miniSuccess: "نسبة النجاح", miniPlaceholders: "أغلفة افتراضية صُنعت",
    btnFinishOpen: "إنهاء وفتح المجلد ✓",
    btnReturnReview: "العودة للشبكة (مراجعة وتغيير) ⮹",
    searchReview: "...ابحث في ألعابك 🔍",
    googleSearchBtn: "افتح بحث صور جوجل 🔍",
    dragDropText: "اسحب وأفلت الصورة هنا، أو اضغط Ctrl+V",
    autoBannerText: "⚡ الوضع التلقائي مفعل. لم أكن متأكداً من هذه اللعبة، يرجى تأكيدها.",
    urlPlaceholder: "أو الصق رابط صورة مباشر / رابط جوجل هنا واضغط Enter...",
    btnBackHome: "العودة للرئيسية",
    ftMainAll: "اختر المجلد الرئيسي لألعابك",
    fsMainAll: "اختر المجلد الرئيسي الذي يحتوي على مجلدات ألعابك الفرعية، أو الصق مساره.",
    btnScanAll: "فحص جميع المجلدات الفرعية ←",
    ftSingle: "اختر مجلد لعبة محدد",
    fsSingle: "اختر مجلد اللعبة الذي تريد تخصيص أيقونته، أو الصق مساره.",
    btnScanSingle: "فحص هذا المجلد ←",
    applyTitle: "جاهز للتطبيق",
    applyMsg: "سيتم تحديث {0} {1} بالأيقونات التي اخترتها.",
    applyDups: "تنبيه: بعض العناصر تشير لنفس اللعبة، لذا ستحصل على نفس الأيقونة: {0}.",
    applySub: "سيتم تعيين الأيقونات الجديدة. ستستمر ألعابك في العمل كما كانت تماماً.",
    btnYesApply: "نعم، قم بالتطبيق الآن",
    btnGoBack: "تراجع",
    memoryTitle: "مرحباً بعودتك!",
    memoryCountMsg: "لديك {0} {1} محفوظة من قبل.",
    memorySub: "أتذكر الألعاب والأغلفة التي اخترتها في المرة السابقة. هل تريدني أن أستخدمها مرة أخرى، أم نبدأ من جديد؟",
    btnUseMemory: "استخدم خياراتي السابقة ✓",
    btnStartOverMemory: "البدء من جديد كلياً",
    choiceSingular: "خيار", choicePlural: "خيارات",
    nounFolder: "مجلد", nounFolders: "مجلدات",
    nounShortcut: "اختصار", nounShortcuts: "اختصارات",
    btnHomeNav: "الرئيسية"
  },
  en: {
    langBtn: "🌐 عربي",
    homeSubtitle: "Find game covers and app icons. Modernize your shortcuts.",
    btnShortcuts: "Game Library Folder",
    descShortcuts: "Recommended. Scan .lnk, .url, Steam/Epic/Ubisoft links, EXE files and emulator ROMs. Build working Windows shortcuts and match game art.",
    btnShortcutsOnly: "Shortcuts Only",
    descShortcutsOnly: "Legacy mode. Scan only existing standard Windows .lnk shortcuts in a folder.",
    btnAllFolders: "All Sub-Folders",
    descAllFolders: "Scan all game folders inside a directory and set their folder icons.",
    btnSingleFolder: "Specific Folder",
    descSingleFolder: "Pick one specific game folder and customize its folder icon.",
    btnSpecific: "Specific Shortcuts",
    descSpecific: "Pick just the shortcuts you want to redo and choose new covers.",
    btnRepair: "Repair Broken Icons",
    descRepair: "Scan a game folder, repair missing .ico references from saved artwork, and refresh the Windows icon cache.",
    btnUndoLast: "↶ Undo Last Change",
    btnProgramIcons: "Program & App Icons",
    descProgramIcons: "Search Google or Yandex Images for app icons and apply them to shortcuts.",
    btnAnyFiles: "Any Files & Scripts",
    descAnyFiles: "Choose .exe, .bat, .cmd, .ps1 and other files. Custom icon shortcuts are created beside regular files.",
    btnGameFiles: "Game Files Folder",
    descGameFiles: "Scan a game folder for playable EXE files and launchers. Create working Windows shortcuts with matching game icons.",
    programFolderTitle: "Choose your program shortcuts folder",
    programFolderSub: "Select the folder that contains your program and app shortcuts, or paste its path.",
    programScanBtn: "Scan shortcuts & choose icons →",
    yandexSearchBtn: "Open Yandex Images Search 🔍",
    customTitle: "Custom Icon Studio",
    kindGame: "Game cover",
    kindProgram: "Program / App icon",
    customSearchHint: "Search for a high-resolution result, then drag it directly onto the drop area or icon preview. You can also right-click an image, choose Copy image, and press Ctrl+V.",
    customApplyBtn: "Apply this icon",
    customSkipBtn: "Skip this app",
    chooseLocalImage: "Choose Local Image",
    btnQuick: "↻ Quick re-apply",
    btnHistory: "🕒 History",
    btnUndo: "↶ Undo / Restore",
    backupTitle: "Undo & Restore Icons",
    backupSubtitle: "Restore previous icon states from saved restore points. A restore point is created automatically before changes are applied.",
    backupRetentionLabel: "Keep restore points:",
    backupEmpty: "No restore points yet. Apply icons once to create your first backup version.",
    backupRestore: "Restore this version",
    backupRestoreConfirm: "This will restore {0} item(s) to their previous state. It may overwrite newer changes to these items. Continue?",
    backupRestoreDone: "Restore completed.",
    backupRestoreError: "The restore point could not be restored.",
    backupSaved: "Restore history setting saved.",
    folderTitle: "Choose your games folder",
    folderSub: "Select the folder that holds your game shortcuts (.lnk), or paste its path.",
    scanBtn: "Scan this folder →",
    backBtn: "← Back",
    stepFolder: "Folder", stepMatch: "Match & Artwork", stepReview: "Review", stepDone: "Done",
    confirmTitle: "Do you like this icon?",
    confirmAutoTitle: "Not sure about this one - do you like it?",
    shortcutProgress: "Item {0} of {1}:  {2}",
    releasedYear: "Released {0}",
    highestConfidence: "Highest-confidence match with its best Grid cover.",
    whichGame: 'Which game is "{0}"?',
    btnLooksGood: "✓ Looks good",
    btnDiffCover: "Choose a different cover",
    btnWrongGame: "The game is wrong",
    btnAutoAll: "⚡ Choose all games & covers automatically",
    btnReturnGrid: "⮩ Return to grid",
    titleMatches: "Pick the correct game",
    titleArtwork: "Choose a cover",
    titleReview: "Pick the ones you don't like and change them",
    subReview: "Click any icons you are not happy with (they dim when selected), then press 'Change these icons'. Happy with all of them? Just press Finish.",
    btnChangeSel: "Change these icons",
    btnFinishApply: "FINISH! (Apply all changes)",
    btnStartOver: "Start over",
    reportTitle: "All done",
    reportSub: "Here is a summary of this run. You can finish, or go back to the grid to review and change any icons.",
    statUpdated: "Updated", statMatched: "Matched", statPlaceholder: "Placeholder", statSkipped: "Skipped", statFailed: "Failed",
    runAtGlance: "THIS RUN AT A GLANCE",
    miniProcessed: "Items processed", miniUpdated: "Icons updated", miniSuccess: "Success rate", miniPlaceholders: "Placeholders made",
    btnFinishOpen: "Finish & open my folder ✓",
    btnReturnReview: "Return to the grid (review & change) ⮹",
    searchReview: "...Search your games 🔍",
    googleSearchBtn: "Open Google Images Search 🔍",
    dragDropText: "Drag & Drop an image here, or press Ctrl+V",
    autoBannerText: "⚡ Auto mode is on. I was not sure about this one, so please confirm it.",
    urlPlaceholder: "or paste a direct image URL / Google link here and press Enter...",
    btnBackHome: "Back to home",
    ftMainAll: "Choose your main games directory",
    fsMainAll: "Select the parent directory that contains all your game sub-folders, or paste its path.",
    btnScanAll: "Scan all sub-folders →",
    ftSingle: "Choose a specific game folder",
    fsSingle: "Select the single game folder whose icon you want to customize, or paste its path.",
    btnScanSingle: "Scan this folder →",
    applyTitle: "Ready to apply",
    applyMsg: "This will update {0} {1} with your chosen icons.",
    applyDups: "Heads up: some items point to the same game, so they will get the same icon: {0}.",
    applySub: "This sets the new icons on your items. They keep working exactly as before.",
    btnYesApply: "Yes, apply now",
    btnGoBack: "Go back",
    memoryTitle: "Welcome back!",
    memoryCountMsg: "You have {0} remembered {1} from before.",
    memorySub: "I remember the games and covers you picked last time. Want me to use those again, or start fresh?",
    btnUseMemory: "Use my previous choices ✓",
    btnStartOverMemory: "Start over from scratch",
    choiceSingular: "choice", choicePlural: "choices",
    nounFolder: "folder", nounFolders: "folders",
    nounShortcut: "shortcut", nounShortcuts: "shortcuts",
    btnHomeNav: "Home"
  },
  tr: {
    langBtn: "Dil",
    homeSubtitle: "Game cover ve app icon'larını bul. Shortcut'larını modernleştir.",
    btnShortcuts: "Game Library Folder",
    descShortcuts: "Önerilen. Klasördeki .lnk ve .url dosyalarını, Steam/Epic/Ubisoft linklerini, EXE dosyalarını ve emulator ROM'larını tara. Çalışan Windows Shortcut'ları oluştur ve uygun Game Artwork eşleştir.",
    btnShortcutsOnly: "Shortcuts Only",
    descShortcutsOnly: "Eski mod. Yalnızca klasördeki mevcut standart Windows .lnk Shortcut'larını tara.",
    btnAllFolders: "All Sub-Folders",
    descAllFolders: "Ana klasörün içindeki tüm oyun klasörlerini tara ve Folder Icon'larını ayarla.",
    btnSingleFolder: "Specific Folder",
    descSingleFolder: "Icon'unu özelleştirmek istediğin tek bir oyun klasörünü seç.",
    btnSpecific: "Specific Shortcuts",
    descSpecific: "Yalnızca yeniden düzenlemek istediğin Shortcut'ları seç ve yeni Cover'lar belirle.",
    btnRepair: "Repair Broken Icons",
    descRepair: "Oyun klasörünü tara, kayıtlı Artwork üzerinden eksik .ico referanslarını onar ve Windows Icon Cache'i yenile.",
    btnUndoLast: "↶ Undo Last Change",
    btnProgramIcons: "Program & App Icons",
    descProgramIcons: "Uygulama Icon'ları için Google Images veya Yandex Images'ta ara ve Shortcut'lara uygula.",
    btnAnyFiles: "Any Files & Scripts",
    descAnyFiles: ".exe, .bat, .cmd, .ps1 ve diğer dosyaları seç. Normal dosyaların yanına özel Icon içeren Shortcut oluşturulur.",
    btnGameFiles: "Game Library Folder",
    descGameFiles: "Oyun klasöründeki çalıştırılabilir EXE dosyalarını ve Launcher'ları tara. Uygun Game Icon'larıyla çalışan Windows Shortcut'ları oluştur.",
    programFolderTitle: "Program Shortcut klasörünü seç",
    programFolderSub: "Program ve uygulama Shortcut'larının bulunduğu klasörü seç veya yolunu yapıştır.",
    programScanBtn: "Shortcut'ları tara ve Icon seç →",
    yandexSearchBtn: "Yandex Images Search'ü aç 🔍",
    customTitle: "Custom Icon Studio",
    kindGame: "Game Cover",
    kindProgram: "Program / App Icon",
    customSearchHint: "Yüksek çözünürlüklü bir sonuç ara. Görseli sürükleyerek Drop alanına veya Icon Preview üzerine bırak. Görsele sağ tıklayıp Copy image seçebilir ve Ctrl+V kullanabilirsin.",
    customApplyBtn: "Bu Icon'u uygula",
    customSkipBtn: "Bu uygulamayı atla",
    chooseLocalImage: "Local Image seç",
    btnQuick: "↻ Quick re-apply",
    btnHistory: "🕒 History",
    btnUndo: "↶ Undo / Restore",
    backupTitle: "Icon'ları Undo / Restore et",
    backupSubtitle: "Kaydedilmiş Restore Point'lerden önceki Icon durumlarını geri yükle. Değişiklikler uygulanmadan önce otomatik Restore Point oluşturulur.",
    backupRetentionLabel: "Saklanacak Restore Point sayısı:",
    backupEmpty: "Henüz Restore Point yok. İlk Backup sürümünü oluşturmak için bir kez Icon uygula.",
    backupRestore: "Bu sürümü Restore et",
    backupRestoreConfirm: "{0} öğe önceki durumuna döndürülecek. Bu işlem daha yeni değişikliklerin üzerine yazabilir. Devam edilsin mi?",
    backupRestoreDone: "Restore tamamlandı.",
    backupRestoreError: "Restore Point geri yüklenemedi.",
    backupSaved: "Restore History ayarı kaydedildi.",
    folderTitle: "Oyun klasörünü seç",
    folderSub: "Game Shortcut'larının (.lnk) bulunduğu klasörü seç veya klasör yolunu yapıştır.",
    scanBtn: "Bu klasörü tara →",
    backBtn: "← Geri",
    stepFolder: "Folder",
    stepMatch: "Match & Artwork",
    stepReview: "Review",
    stepDone: "Done",
    confirmTitle: "Bu Icon uygun mu?",
    confirmAutoTitle: "Bu eşleşmeden tam emin değilim. Sence uygun mu?",
    shortcutProgress: "Öğe {0} / {1}: {2}",
    releasedYear: "Çıkış yılı: {0}",
    highestConfidence: "Mevcut en iyi Grid Cover ile en yüksek güvenli eşleşme.",
    whichGame: '“{0}” hangi oyun?',
    btnLooksGood: "✓ Uygun",
    btnDiffCover: "Farklı Cover seç",
    btnWrongGame: "Eşleşen oyun yanlış",
    btnAutoAll: "⚡ Tüm oyun ve Cover'ları otomatik seç",
    btnReturnGrid: "⮩ Grid'e dön",
    titleMatches: "Doğru oyunu seç",
    titleArtwork: "Bir Cover seç",
    titleReview: "Beğenmediğin Icon'ları seç ve değiştir",
    subReview: "Memnun olmadığın Icon'lara tıkla (seçildiğinde soluklaşırlar), sonra 'Change these icons' düğmesine bas. Hepsi uygunsa Finish'e basman yeterli.",
    btnChangeSel: "Seçili Icon'ları değiştir",
    btnFinishApply: "BİTİR! (Tüm değişiklikleri uygula)",
    btnStartOver: "Baştan başla",
    reportTitle: "Tamamlandı",
    reportSub: "Bu işlemin özeti burada. Bitirebilir veya Grid'e dönerek Icon'ları yeniden inceleyip değiştirebilirsin.",
    statUpdated: "Güncellendi",
    statMatched: "Eşleşti",
    statPlaceholder: "Placeholder",
    statSkipped: "Atlandı",
    statFailed: "Başarısız",
    runAtGlance: "İŞLEMİN KISA ÖZETİ",
    miniProcessed: "İşlenen öğe",
    miniUpdated: "Güncellenen Icon",
    miniSuccess: "Başarı oranı",
    miniPlaceholders: "Oluşturulan Placeholder",
    btnFinishOpen: "Bitir ve klasörümü aç ✓",
    btnReturnReview: "Grid'e dön (incele ve değiştir) ⮹",
    searchReview: "...Oyunlarında ara 🔍",
    googleSearchBtn: "Google Images Search'ü aç 🔍",
    dragDropText: "Görseli buraya sürükle ve bırak veya Ctrl+V'ye bas",
    autoBannerText: "⚡ Auto Mode açık. Bu eşleşmeden emin olamadım; lütfen onayla.",
    urlPlaceholder: "veya doğrudan Image URL / Google linkini yapıştırıp Enter'a bas...",
    btnBackHome: "Ana sayfaya dön",
    ftMainAll: "Ana oyun klasörünü seç",
    fsMainAll: "Tüm oyun alt klasörlerini içeren ana klasörü seç veya yolunu yapıştır.",
    btnScanAll: "Tüm alt klasörleri tara →",
    ftSingle: "Belirli bir oyun klasörü seç",
    fsSingle: "Icon'unu özelleştirmek istediğin tek oyun klasörünü seç veya yolunu yapıştır.",
    btnScanSingle: "Bu klasörü tara →",
    applyTitle: "Uygulamaya hazır",
    applyMsg: "Seçtiğin Icon'lar {0} {1} öğeyi güncelleyecek.",
    applyDups: "Dikkat: Bazı öğeler aynı oyuna işaret ediyor; bu nedenle aynı Icon'u alacaklar: {0}.",
    applySub: "Seçtiğin yeni Icon'lar öğelere atanacak. Kısayolların eskisi gibi çalışmaya devam edecek.",
    btnYesApply: "Evet, şimdi uygula",
    btnGoBack: "Geri dön",
    memoryTitle: "Tekrar hoş geldin!",
    memoryCountMsg: "Önceki işlemlerinden {0} kayıtlı {1} bulundu.",
    memorySub: "Daha önce seçtiğin oyunları ve Cover'ları hatırlıyorum. Aynı seçimleri yeniden kullanmak mı, yoksa sıfırdan başlamak mı istersin?",
    btnUseMemory: "Önceki seçimlerimi kullan ✓",
    btnStartOverMemory: "Sıfırdan başla",
    choiceSingular: "seçim",
    choicePlural: "seçim",
    nounFolder: "klasör",
    nounFolders: "klasör",
    nounShortcut: "Shortcut",
    nounShortcuts: "Shortcut",
    btnHomeNav: "Ana Sayfa"
  }
};
var screenI18n = {
  en: {
    refresh:"Refresh", keyTitle:"Let's get you set up",
    keyIntro:"Game Icons Studio finds game covers through SteamGridDB. A free API key is needed for automatic game matching, but not for Program & App Icons.",
    keyNew:"New here?", keyExisting:"Already have an account?",
    keySteps:["Open SteamGridDB and click Login (top right).","Sign in with Steam — this creates your free account instantly.","Come back and use the other button to get your key.","Open your API settings with the button below.","Click Create API Key, then Copy it.","Paste it here and you're ready to go."],
    keyCreate:"Create a SteamGridDB account", keyGet:"Get my API key", keyPlaceholder:"Paste your API key here",
    keyPaste:"📋 Paste & continue", keyContinue:"Continue", keyNoKey:"Continue with Program & App Icons (no API key)",
    keyStorageNotice:"Your API Key is stored only in this browser's localStorage. It is never written to settings.json or GitHub.", keyRequiredMessage:"A valid SteamGridDB API Key is required for game artwork matching. You can still use Program & App Icons without a key.",
    noArtTitle:"No cover art for this one",
    noArtDescription:"SteamGridDB doesn't have artwork for this game yet. Game Icons Studio can create a clean placeholder Icon with the game's name, matching your other Icons.",
    historyTitle:"Your Icon History", historySubtitle:"The most recent Icon changes you have made.", historyPlaceholder:"🔍 Search History...",
    historyEmpty:"No History yet. Once you apply Icons, your changes will appear here.", historyBack:"⌂ Back to Home",
    aboutTitle:"What is GIS? (Game Icons Studio)", aboutSubtitle:"A quick tour, so you know what this app does and how to use it.",
    aboutHeadings:["🎮 What it is","🔌 Where the Artwork comes from","⚡ How it works (3 steps)","🧩 What each button does","📊 The Summary screen","💾 Safe and non-destructive"],
    aboutBodies:[
      "Game Icons Studio turns generic game and program Shortcut Icons into polished Icons. Match game covers through SteamGridDB, or find app Icons through Google Images and Yandex Images. Preview and apply them locally.",
      "Game covers are matched through SteamGridDB. For regular applications, use Program & App Icons to search Google Images or Yandex Images. Drag and drop or copy/paste an image; processing happens locally. The SteamGridDB API key is only required for game matching.",
      "1. Choose a folder of game Shortcuts (.lnk). The app scans them and matches each to a game. 2. Review the selected covers and change any you don't like. 3. Apply. The app backs up the old Icons, sets the new ones and refreshes Windows.",
      "Game Library Folder — scan game links and files. Program & App Icons — find application Icons. Specific Shortcuts — choose selected links to update. Repair Broken Icons — fix missing Icon references. Quick re-apply — reuse your saved choices. History — review past changes.",
      "After applying, review how many Icons were updated, matched, created as placeholders, skipped or failed. Finish, or return to the Grid to review and change Icons.",
      "Game Icons Studio changes Shortcut Icons, not the installed game files. Your original game files remain untouched. Restore Points let you reverse supported changes."
    ],
    aboutHome:"⌂ Go to Home",
    convertSuccessTitle:"Conversion successful!", convertSuccessBody:"Your launcher links are now standard .lnk files, so their Icons can be customized properly. The links keep working as before.", convertContinue:"Continue →",
    doneTitle:"Done", doneHome:"⌂ Back to Home",
    healthTitle:"Here's what I found", healthSubtitle:"A quick look at your folder before we start.", healthContinue:"Continue →", cancel:"Cancel",
    newGamesTitle:"New files and shortcuts found", newGamesPrompt:"New files or shortcuts have appeared since the last completed scan. Process only those items, or scan the entire folder?",
    newGamesOnly:"Only new files / shortcuts", newGamesAll:"Scan everything",
    convertTitle:"We found some launcher Shortcuts",
    convertBody1:"Some items are Internet Shortcuts (.url), not standard Windows Shortcuts (.lnk). Windows does not let us assign custom Icons to .url files directly.",
    convertBody2:"Game Icons Studio can convert them automatically. Your links keep working the same way; they become standard Shortcuts that can display your new Icons.",
    convertProceed:"Convert & continue", convertSkip:"Skip; scan .lnk files only",
    folderBrowse:"📁 Browse for Folder…", folderPlaceholder:"…or paste a folder path here and press Enter",
    loadingWorking:"Working…", loadingWait:"Waiting for live progress…",
    grid:"▦ Grid", gallery:"▤ Gallery", onlineTitle:"Smart online Icon candidates",
    onlineDesc:"Google and Yandex results ranked by square shape, resolution and likely Icon relevance.",
    onlineBoth:"Find more from both", onlineGoogle:"Google only", onlineYandex:"Yandex only",
    onlineStatus:"Choose Google or Yandex Images, then drag the image into the highlighted drop area.",
    dropHelp:"Drag an image from Google Images or Yandex Images here. You can also right-click it and choose Copy image, then press Ctrl+V, or click to browse your PC.",
    previewTitle:"ICON PREVIEW (1:1)", previewDropTitle:"You can also drop an image directly onto this Preview", canvasDropTitle:"Drop an image here to Preview it", crop:"Crop 1:1", fit:"Fit", stretch:"Stretch", loadUrl:"Load URL", cancelSkip:"← Cancel / Skip",
        retentionOptions:["Last 10 versions","Last 25 versions","Last 50 versions","Last 100 versions","Unlimited (uses more disk space)"],
    languageGroupLabel:"Language", themeNames:["Aurora Glass","Dark","Light","Modern Dark","Modern Light","Gaming","Minimal"], zoomOutTitle:"Smaller (-)", zoomInTitle:"Bigger (+)", fullscreenTitle:"Fullscreen (F)", homeHeader:"⌂ Home", aboutHeader:"❔ What is GIS?", summaryHeader:"↶ Summary",
    cycleTheme:"Change theme",
    fullScreen:"⛶ Fullscreen", exitFullscreen:"⛶ Exit Fullscreen", quit:"Quit",
    gameFilesTitle:"Find games inside a folder", gameFilesDesc:"Scan launcher links, game files and ROMs recursively. Existing Shortcuts are kept; original files stay untouched.", gameFilesButton:"Scan game library",
    repairSummary:"Icon repair results", altIconMatch:"Choose a different match", iconReviewTitle:"Review this program / file icon", iconSearchHint:"Review the Preview. You can choose a different image from Google, Yandex or your PC.", programIconTitle:"Choose a program icon", altIconResults:"Alternative Icon results for ", altIconTitle:"Choose an alternative Icon result", browseFolderDetail:"Choose a game installation or library folder. I will find playable EXE files, Launcher links and ROMs inside it.", browseFolderGeneric:"A Windows folder window will appear in front. Pick your games folder and click OK.",
    noArtButtons:["✧ Generate a placeholder Icon","Try a different game","🔎 Google / Custom Cover"], browseFolderAll:"A Windows folder window will appear in front. Choose the parent folder that contains your game folders, then click OK.", browseFolderSingle:"A Windows folder window will appear in front. Choose the game folder whose Icon you want to customize, then click OK.", noImageArtwork:"No cover art is available for this game yet.",
  },
  tr: {
    refresh:"Yenile", keyTitle:"Kuruluma başlayalım",
    keyIntro:"Game Icons Studio, oyun Cover'larını SteamGridDB üzerinden bulur. Otomatik game eşleştirmesi için ücretsiz API Key gerekir; Program & App Icons modu için gerekmez.",
    keyNew:"Yeni misin?", keyExisting:"Zaten hesabın var mı?",
    keySteps:["SteamGridDB'yi aç ve sağ üstten Login'e tıkla.","Steam ile Sign in yap; ücretsiz hesabın hemen oluşturulur.","Geri dön ve API Key almak için diğer düğmeyi kullan.","Aşağıdaki düğmeyle API ayarlarını aç.","Create API Key'e, ardından Copy'ye tıkla.","Key'i buraya yapıştır; hazırsın."],
    keyCreate:"SteamGridDB hesabı oluştur", keyGet:"API Key'imi al", keyPlaceholder:"API Key'ini buraya yapıştır",
    keyPaste:"📋 Yapıştır ve devam et", keyContinue:"Devam et", keyNoKey:"Program & App Icons ile devam et (API Key gerekmez)",
    keyStorageNotice:"API Key'in yalnızca bu tarayıcının localStorage alanında saklanır. settings.json dosyasına veya GitHub'a yazılmaz.", keyRequiredMessage:"Oyun Artwork eşleştirmesi için geçerli bir SteamGridDB API Key gerekir. API Key olmadan Program & App Icons özelliğini kullanabilirsin.",
    noArtTitle:"Bu oyun için Cover bulunamadı",
    noArtDescription:"SteamGridDB'de bu oyun için henüz Artwork yok. Game Icons Studio, diğer Icon'larınla uyumlu, oyunun adını taşıyan sade bir Placeholder Icon oluşturabilir.",
    historyTitle:"Icon History", historySubtitle:"Şimdiye kadar yaptığın en son Icon değişiklikleri.", historyPlaceholder:"🔍 History içinde ara...",
    historyEmpty:"Henüz History yok. Icon uyguladığında değişikliklerin burada görünecek.", historyBack:"⌂ Ana Sayfaya Dön",
    aboutTitle:"GIS nedir? (Game Icons Studio)", aboutSubtitle:"Uygulamanın ne yaptığını ve nasıl kullanıldığını anlatan kısa bir tur.",
    aboutHeadings:["🎮 Ne işe yarar?","🔌 Artwork nereden gelir?","⚡ Nasıl çalışır? (3 adım)","🧩 Düğmeler ne işe yarar?","📊 Summary ekranı","💾 Güvenli ve geri alınabilir"],
    aboutBodies:[
      "Game Icons Studio, oyun ve program Shortcut'larının sıradan Icon'larını daha şık Icon'lara dönüştürür. Oyun Cover'larını SteamGridDB ile eşleştirir; uygulama Icon'larını Google Images veya Yandex Images üzerinden bulmana yardımcı olur. Sonuçları yerel olarak Preview eder ve uygular.",
      "Oyun Cover'ları SteamGridDB üzerinden eşleştirilir. Diğer uygulamalar için Program & App Icons bölümünden Google Images veya Yandex Images'ta ara. Görseli sürükleyip bırakabilir veya kopyalayıp yapıştırabilirsin; işlem bilgisayarında yapılır. SteamGridDB API Key yalnızca oyun eşleştirmesi için gerekir.",
      "1. Game Shortcut'larının (.lnk) bulunduğu klasörü seç. Uygulama onları tarar ve oyunlarla eşleştirir. 2. Seçilen Cover'ları Review et, beğenmediklerini değiştir. 3. Apply. Uygulama eski Icon'ları yedekler, yenilerini atar ve Windows'u yeniler.",
      "Game Library Folder — oyun linklerini ve dosyalarını tara. Program & App Icons — uygulama Icon'larını bul. Specific Shortcuts — seçtiğin linkleri güncelle. Repair Broken Icons — kayıp Icon referanslarını onar. Quick re-apply — kayıtlı seçimlerini tekrar kullan. History — önceki işlemleri incele.",
      "Apply işleminden sonra güncellenen, eşleşen, Placeholder olarak oluşturulan, atlanan veya başarısız olan Icon sayılarını görürsün. Finish ile tamamla veya Grid'e dönüp Icon'ları yeniden incele.",
      "Game Icons Studio, kurulu oyun dosyalarını değil Shortcut Icon'larını değiştirir. Orijinal oyun dosyaların olduğu gibi kalır. Restore Point, desteklenen değişiklikleri geri almanı sağlar."
    ],
    aboutHome:"⌂ Ana Sayfaya Git",
    convertSuccessTitle:"Dönüştürme başarılı!", convertSuccessBody:"Launcher linklerin artık standart .lnk dosyaları. Böylece Icon'ları özelleştirilebilir. Kısayolların eskisi gibi çalışmaya devam eder.", convertContinue:"Devam et →",
    doneTitle:"Tamamlandı", doneHome:"⌂ Ana Sayfaya Dön",
    healthTitle:"Klasöründe bunları buldum", healthSubtitle:"Başlamadan önce klasörüne hızlı bir göz atalım.", healthContinue:"Devam et →", cancel:"İptal",
    newGamesTitle:"Yeni dosya ve kısayollar bulundu", newGamesPrompt:"Son tamamlanan taramadan sonra yeni dosya veya kısayol eklenmiş. Yalnızca yenilerini mi, yoksa tüm klasörü mü taramak istersin?",
    newGamesOnly:"Yalnızca yeni dosya / kısayollar", newGamesAll:"Her şeyi tara",
    convertTitle:"Bazı Launcher Shortcut'ları bulduk",
    convertBody1:"Bazı öğelerin standart Windows Shortcut'ı (.lnk) yerine Internet Shortcut (.url). Windows, .url dosyalarına doğrudan özel Icon atamamıza izin vermiyor.",
    convertBody2:"Game Icons Studio bunları otomatik dönüştürebilir. Linklerin aynı şekilde çalışır; yalnızca yeni Icon gösterebilen standart Shortcut'lara dönüşür.",
    convertProceed:"Dönüştür ve devam et", convertSkip:"Atla; yalnızca .lnk dosyalarını tara",
    folderBrowse:"📁 Klasör seç…", folderPlaceholder:"…veya klasör yolunu buraya yapıştırıp Enter'a bas",
    loadingWorking:"İşleniyor…", loadingWait:"Canlı işlem bilgisi bekleniyor…",
    grid:"▦ Grid", gallery:"▤ Gallery", onlineTitle:"Akıllı Online Icon adayları",
    onlineDesc:"Google ve Yandex sonuçları kare oranı, çözünürlük ve Icon uygunluğuna göre sıralanır.",
    onlineBoth:"İki kaynaktan da daha fazla bul", onlineGoogle:"Yalnızca Google", onlineYandex:"Yalnızca Yandex",
    onlineStatus:"Google veya Yandex Images ile arama yap; görseli vurgulanan bırakma alanına sürükle.",
    dropHelp:"Google Images veya Yandex Images'tan görseli buraya sürükle. Sağ tıklayıp Copy image seçerek Ctrl+V yapabilir ya da bilgisayarından seçmek için tıklayabilirsin.",
    previewTitle:"ICON PREVIEW (1:1)", previewDropTitle:"Bu Preview alanına da doğrudan görsel bırakabilirsin", canvasDropTitle:"Önizlemek için görseli buraya bırak", crop:"Crop 1:1", fit:"Fit", stretch:"Stretch", loadUrl:"URL yükle", cancelSkip:"← İptal / Atla",
        retentionOptions:["Son 10 sürüm","Son 25 sürüm","Son 50 sürüm","Son 100 sürüm","Sınırsız (daha fazla disk alanı kullanır)"],
    languageGroupLabel:"Dil", themeNames:["Aurora Glass","Koyu","Açık","Modern Koyu","Modern Açık","Gaming","Minimal"], zoomOutTitle:"Küçült (-)", zoomInTitle:"Büyüt (+)", fullscreenTitle:"Tam Ekran (F)", homeHeader:"⌂ Ana Sayfa", aboutHeader:"❔ GIS nedir?", summaryHeader:"↶ Summary",
    cycleTheme:"Tema değiştir",
    fullScreen:"⛶ Tam Ekran", exitFullscreen:"⛶ Tam Ekrandan Çık", quit:"Çıkış",
    gameFilesTitle:"Klasördeki oyunları bul", gameFilesDesc:"Alt klasörler dâhil Launcher linklerini, oyun dosyalarını ve ROM'ları tara. Mevcut Shortcut'lar korunur; orijinal dosyalara dokunulmaz.", gameFilesButton:"Game Library'yi tara",
    repairSummary:"Icon onarım sonuçları", altIconMatch:"Farklı bir eşleşme seç", iconReviewTitle:"Bu Program / Dosya için Icon'u incele", iconSearchHint:"Preview'i incele. Google, Yandex veya bilgisayarından farklı bir görsel seçebilirsin.", programIconTitle:"Bir Program Icon'u seç", altIconResults:"Alternatif Icon sonuçları: ", altIconTitle:"Alternatif bir Icon sonucu seç", browseFolderDetail:"Oyun kurulum veya kütüphane klasörünü seç. İçindeki EXE dosyalarını, Launcher linklerini ve ROM'ları bulacağım.", browseFolderGeneric:"Önde bir Windows klasör penceresi açılacak. Oyun klasörünü seçip OK'e bas.",
    noArtButtons:["✧ Placeholder Icon oluştur","Farklı bir oyun dene","🔎 Google / Custom Cover"], browseFolderAll:"Önde bir Windows klasör penceresi açılacak. Oyun klasörlerini içeren ana klasörü seçip OK'e bas.", browseFolderSingle:"Önde bir Windows klasör penceresi açılacak. Icon'unu özelleştirmek istediğin oyun klasörünü seçip OK'e bas.", noImageArtwork:"Bu oyun için henüz Cover Artwork bulunamadı.",
  },
  ar: {
    refresh:"تحديث", keyTitle:"لنبدأ إعداد التطبيق",
    keyIntro:"يعثر Game Icons Studio على أغلفة الألعاب عبر SteamGridDB. يلزم API Key مجاني للمطابقة التلقائية للألعاب، ولا يلزم ذلك لميزة Program & App Icons.",
    keyNew:"هل أنت جديد هنا؟", keyExisting:"هل لديك حساب بالفعل؟",
    keySteps:["افتح SteamGridDB واضغط Login في أعلى اليمين.","سجّل الدخول باستخدام Steam لإنشاء حسابك المجاني فوراً.","ارجع إلى هنا واستخدم الزر الآخر للحصول على المفتاح.","افتح إعدادات API باستخدام الزر أدناه.","اضغط Create API Key ثم Copy.","الصق المفتاح هنا وأنت جاهز."],
    keyCreate:"إنشاء حساب SteamGridDB", keyGet:"الحصول على API Key", keyPlaceholder:"الصق API Key هنا",
    keyPaste:"📋 لصق ومتابعة", keyContinue:"متابعة", keyNoKey:"المتابعة باستخدام Program & App Icons (من دون API Key)",
    keyStorageNotice:"يُحفظ API Key في localStorage لهذا المتصفح فقط. ولا تتم كتابته في settings.json أو GitHub.", keyRequiredMessage:"يلزم SteamGridDB API Key صالح لمطابقة صور الألعاب. يمكنك استخدام Program & App Icons من دون مفتاح.",
    noArtTitle:"لا يوجد غلاف لهذه اللعبة",
    noArtDescription:"لا تتوفر Artwork لهذه اللعبة في SteamGridDB بعد. يمكن لـ Game Icons Studio إنشاء Placeholder Icon بسيط باسم اللعبة ليتناسق مع بقية الأيقونات.",
    historyTitle:"سجل الأيقونات", historySubtitle:"أحدث تغييرات الأيقونات التي أجريتها.", historyPlaceholder:"🔍 البحث في السجل...",
    historyEmpty:"لا يوجد سجل بعد. ستظهر تغييراتك هنا بعد تطبيق الأيقونات.", historyBack:"⌂ العودة إلى الرئيسية",
    aboutTitle:"ما هو GIS؟ (Game Icons Studio)", aboutSubtitle:"جولة سريعة للتعرّف على التطبيق وطريقة استخدامه.",
    aboutHeadings:["🎮 ما وظيفة التطبيق؟","🔌 من أين تأتي الصور؟","⚡ كيف يعمل؟ (3 خطوات)","🧩 وظيفة الأزرار","📊 شاشة الملخص","💾 آمن وغير إتلافي"],
    aboutBodies:[
      "يحوّل Game Icons Studio الأيقونات العامة لاختصارات الألعاب والبرامج إلى أيقونات أنيقة. يطابق أغلفة الألعاب عبر SteamGridDB، ويساعدك في العثور على أيقونات التطبيقات عبر Google Images أو Yandex Images، ثم يعرضها ويطبقها محلياً.",
      "تتم مطابقة أغلفة الألعاب عبر SteamGridDB. للتطبيقات العادية استخدم Program & App Icons للبحث في Google Images أو Yandex Images. اسحب الصورة أو انسخها والصقها؛ تتم المعالجة محلياً. لا تحتاج إلى SteamGridDB API Key إلا لمطابقة الألعاب.",
      "1. اختر مجلداً يحتوي على اختصارات الألعاب (.lnk). يفحصها التطبيق ويطابق كل اختصار مع لعبة. 2. راجع الأغلفة المختارة وغيّر ما لا يعجبك. 3. طبّق التغييرات؛ سيحفظ التطبيق نسخة من الأيقونات القديمة ثم يحدّث Windows.",
      "Game Library Folder — فحص روابط وملفات الألعاب. Program & App Icons — العثور على أيقونات التطبيقات. Specific Shortcuts — اختيار روابط محددة للتحديث. Repair Broken Icons — إصلاح مراجع الأيقونات المفقودة. Quick re-apply — استخدام اختياراتك المحفوظة. History — مراجعة التغييرات السابقة.",
      "بعد التطبيق، راجع عدد الأيقونات التي تم تحديثها أو مطابقتها أو إنشاؤها كـ Placeholder أو تخطيها أو فشلها. اضغط Finish أو ارجع إلى Grid لمراجعتها وتغييرها.",
      "يغيّر Game Icons Studio أيقونات الاختصارات فقط، ولا يغيّر ملفات الألعاب المثبتة. تبقى ملفاتك الأصلية كما هي. تساعدك Restore Points على التراجع عن التغييرات المدعومة."
    ],
    aboutHome:"⌂ الانتقال إلى الرئيسية",
    convertSuccessTitle:"تم التحويل بنجاح!", convertSuccessBody:"أصبحت روابط Launcher ملفات .lnk قياسية، ويمكن الآن تخصيص أيقوناتها. ستستمر الروابط في العمل كما كانت.", convertContinue:"متابعة →",
    doneTitle:"تم", doneHome:"⌂ العودة إلى الرئيسية",
    healthTitle:"هذه هي العناصر التي وجدتها", healthSubtitle:"نظرة سريعة على المجلد قبل البدء.", healthContinue:"متابعة →", cancel:"إلغاء",
    newGamesTitle:"تم العثور على ملفات واختصارات جديدة", newGamesPrompt:"تمت إضافة ملفات أو اختصارات منذ آخر فحص مكتمل. هل تريد معالجة العناصر الجديدة فقط أم فحص المجلد بالكامل؟",
    newGamesOnly:"الملفات والاختصارات الجديدة فقط", newGamesAll:"فحص الكل",
    convertTitle:"وجدنا بعض اختصارات Launcher",
    convertBody1:"بعض العناصر هي Internet Shortcuts (.url) وليست Windows Shortcuts قياسية (.lnk). لا يسمح Windows بتعيين أيقونات مخصصة لملفات .url مباشرة.",
    convertBody2:"يمكن لـ Game Icons Studio تحويلها تلقائياً. ستعمل الروابط بالطريقة نفسها، لكنها ستصبح اختصارات قياسية تعرض الأيقونات الجديدة.",
    convertProceed:"تحويل ومتابعة", convertSkip:"تخطي؛ فحص ملفات .lnk فقط",
    folderBrowse:"📁 استعراض المجلد…", folderPlaceholder:"…أو الصق مسار المجلد هنا واضغط Enter",
    loadingWorking:"جارٍ العمل…", loadingWait:"بانتظار تقدم العملية المباشر…",
    grid:"▦ Grid", gallery:"▤ Gallery", onlineTitle:"اقتراحات ذكية للأيقونات عبر الإنترنت",
    onlineDesc:"ترتيب نتائج Google وYandex حسب الشكل المربع والدقة ومدى ملاءمتها كأيقونة.",
    onlineBoth:"المزيد من المصدرين", onlineGoogle:"Google فقط", onlineYandex:"Yandex فقط",
    onlineStatus:"اختر صور Google أو Yandex ثم اسحب الصورة إلى منطقة الإفلات المحددة.",
    dropHelp:"اسحب صورة من Google Images أو Yandex Images إلى هنا. يمكنك أيضاً النقر بزر الفأرة الأيمن واختيار Copy image ثم الضغط على Ctrl+V، أو النقر لاختيار صورة من جهازك.",
    previewTitle:"معاينة الأيقونة (1:1)", previewDropTitle:"يمكنك أيضاً إسقاط صورة مباشرة على هذه المعاينة", canvasDropTitle:"أسقط صورة هنا لمعاينتها", crop:"Crop 1:1", fit:"Fit", stretch:"Stretch", loadUrl:"تحميل URL", cancelSkip:"← إلغاء / تخطي",
        retentionOptions:["آخر 10 إصدارات","آخر 25 إصداراً","آخر 50 إصداراً","آخر 100 إصدار","غير محدود (يستخدم مساحة أكبر من القرص)"],
    languageGroupLabel:"اللغة", themeNames:["Aurora Glass","داكن","فاتح","داكن عصري","فاتح عصري","Gaming","Minimal"], zoomOutTitle:"تصغير (-)", zoomInTitle:"تكبير (+)", fullscreenTitle:"ملء الشاشة (F)", homeHeader:"⌂ الرئيسية", aboutHeader:"❔ ما هو GIS؟", summaryHeader:"↶ الملخص",
    cycleTheme:"تغيير السمة",
    fullScreen:"⛶ ملء الشاشة", exitFullscreen:"⛶ الخروج من ملء الشاشة", quit:"خروج",
    gameFilesTitle:"العثور على الألعاب داخل مجلد", gameFilesDesc:"افحص روابط Launcher وملفات الألعاب وROM داخل المجلدات الفرعية. تبقى الاختصارات والملفات الأصلية دون تغيير.", gameFilesButton:"فحص مكتبة الألعاب",
    repairSummary:"نتائج إصلاح الأيقونات", altIconMatch:"اختر مطابقة أخرى", iconReviewTitle:"راجع أيقونة البرنامج / الملف", iconSearchHint:"راجع Preview. يمكنك اختيار صورة أخرى من Google أو Yandex أو من جهازك.", programIconTitle:"اختر أيقونة البرنامج", altIconResults:"نتائج الأيقونات البديلة لـ ", altIconTitle:"اختر نتيجة أيقونة بديلة", browseFolderDetail:"اختر مجلد تثبيت اللعبة أو مكتبتها. سأبحث عن ملفات EXE وروابط Launcher وملفات ROM داخله.", browseFolderGeneric:"ستظهر نافذة مجلدات Windows في المقدمة. اختر مجلد الألعاب واضغط OK.",
    noArtButtons:["✧ إنشاء Placeholder Icon","جرّب لعبة أخرى","🔎 Google / Custom Cover"], browseFolderAll:"ستظهر نافذة مجلدات Windows في المقدمة. اختر المجلد الرئيسي الذي يحتوي على مجلدات الألعاب ثم اضغط OK.", browseFolderSingle:"ستظهر نافذة مجلدات Windows في المقدمة. اختر مجلد اللعبة الذي تريد تخصيص أيقونته ثم اضغط OK.", noImageArtwork:"لا تتوفر Artwork لهذه اللعبة بعد.",
  }
};

var statusI18n = {
  en: {
    gettingReady:"Getting ready to re-apply…", loadingSavedChoices:"Loading your last folder and saved choices.", checkingSavedBackups:"Checking saved Icon Backups.", restoringPreviousState:"Restoring the previous Icon state…", reversingLatest:"Reversing the latest saved Icon transaction.",     chooseRepairFolder:"Choose a folder to repair…", repairFolderDetail:"Select the game library or Shortcuts folder whose Icons appear blank or white.", repairingIcons:"Repairing Shortcut Icons…", repairingDetail:"Checking persistent ICO files, rebuilding available Icons from cached Artwork, and refreshing Windows Explorer.", selectFilesDetail:"A Windows window will appear in front. Ctrl+click the Shortcuts you want to update, then click Open.", findingProgramIcons:"Finding the best Program Icons…", scanningGames:"Scanning your games…", waitingForApply:"Waiting for live progress from the actual download, build, Backup and apply steps.", stopped:"Stopped", noSupportedFiles:"No supported files or Program Shortcuts were found.", noGamesMatched:"No matchable games were found.",     programFilesScanning:"Finding Program and file Icons…", readingFiles:"Reading the files you selected…",
    applyPreparing:"Preparing your Icon update…", applyStarting:"Starting the apply pipeline…", applyComplete:"All reported operations have finished.", applyFinishedDetail:"The operation has finished. Review the results below for failed or skipped items.", progressConnectionLost:"The browser lost the live progress connection. Check the CMD log before retrying, to avoid repeating an operation that may have completed.",
        invalidKey:"That API Key did not work. Check it and try again.", fileScanError:"Could not read the files you selected.", applyFailed:"Apply failed.", standardShortcuts:"Standard Shortcuts", launcherShortcuts:"Launcher Shortcuts (.url)", brokenTargetLabel:"Broken / missing target", launcherConversionNote:"Launcher Shortcuts can be converted so their Icons can be customized.", brokenTargetNote:"Some Shortcuts point to missing files; those items will be skipped safely.",     noPreviousFolder:"There is no previous folder to re-apply yet. Scan a folder first.",
    noSavedChoices:"You have no saved choices to re-apply yet.",
    noUnusedRestore:"There is no unused Restore Point yet. Apply an Icon change first to create a Backup.",
    undoConfirm:"Undo the latest Icon change from {0}? This will restore {1} item(s) and remove Shortcuts created by that change.",
    latestRestoreError:"The latest Restore Point could not be restored.",
    backupListError:"Could not read Restore Points. Check the application log.",
    historyEmpty:"No History yet. Once you apply Icons, your changes will appear here.",
    backupSaveError:"Could not save the Restore Point setting.",
    repairError:"The Icon Repair operation could not be completed.",
    repairRequestError:"The Icon Repair request failed.",
    pickerError:"Could not open the Windows folder picker.",
    lastFolderReady:"Last used folder is ready. Press Scan, or browse/paste another path.",
    noFolderChosen:"No folder chosen. Try again, or paste a path above.",
    folderReady:"Folder ready. Starting…",
    invalidFolderPath:"That path does not exist. Check it and try again.",
    gameFolderScanError:"Could not scan this game folder.",
    gameFolderScanFailed:"The game folder could not be scanned.",
    scanFailed:"Scan failed.",
    newGamesCount:"{0} new file(s) or shortcut(s) have been added since the last completed scan.",
    launcherCount:"Found {0} Launcher Shortcut(s){1}.",
    andShortcutCount:" and {0} standard Shortcut(s)",
    openingFolder:"Opening the Windows folder picker…",
    findingGames:"Finding games and launchers…",
    scanningFolder:"Scanning this folder for existing Shortcuts and playable game files.",
    autoLoading:"Choosing your games and covers automatically",
    autoDetail:"I will only stop to ask when I am not confident about a game match.",
    matchingProgress:"Matched {0} of {1}.",
    checkingFolder:"Checking your folder…",
    checkingShortcuts:"Looking at your Shortcuts…",
    convertingShortcuts:"Converting your Shortcuts…",
    convertingDetail:"This keeps them working and lets them show new Icons.",
    working:"Working…",
    loadingBackups:"Loading Restore Points…",
    readingBackups:"Reading saved Icon versions.",
    restoringIcons:"Restoring previous Icons…",
    restoringDetail:"Restoring the saved Shortcut and Folder state.",
    loadingHistory:"Loading your History…",
    checkingKey:"Checking your API Key…",
    needKey:"Please paste your API Key first.",
    clipboardError:"Could not read the clipboard. Paste with Ctrl+V, then Continue.",
    pasteKeyHint:"Paste with Ctrl+V into the box, then press Continue.",
    progressInterrupted:"Progress stream interrupted",
    checkStatus:"Check status",
    updateFailed:"The update could not be completed.",
    checkLog:"Check the application log and try again.",
    updateStopped:"Update stopped safely",
    noIconsChanged:"No Icons were changed",
    restorePointFailed:"The Restore Point could not be created, so the app stopped before changing any Shortcuts.",
    complete:"Complete",
    finishedIssues:"Finished with some issues",
    shelfReady:"Done! Your game shelf is ready.",
    progressLive:"Live progress is based on completed operations, not a timer.",
    noArtCandidates:"No embedded online candidates yet. Use Find more from both, open a search tab, or drag/copy an image into the Preview.",
    onlineLoading:"No automatic candidates yet. Searching Google Images and Yandex Images…",
    onlineNoResults:"No direct result images could be extracted. Google/Yandex tabs and drag-and-drop remain available.",
    onlineFailed:"Online result retrieval failed. Open Google/Yandex in a tab or drag/drop an image into the Preview.",
    loadingPreview:"Loading the selected image into the 1:1 Preview…",
    useImage:"Use this image",
    candidate:"Candidate",
    quality:"quality",
    nearSquare:"near-square",
    notSquare:"not square",
    launchableEntries:"launchable entries found", exeFiles:"EXE", scriptFiles:"BAT/CMD", existingLinks:"existing Shortcuts", urlPrepared:"Launcher URLs prepared as .lnk", romFiles:"emulator ROMs", alreadyLinked:"already had a working Shortcut", launcherUtilities:"Launcher utility Shortcuts left alone", installerHelpers:"installer/helper files skipped", urlsKept:"URL conversion(s) kept as source files", safetyLimit:"safety limit", extraEntries:"extra entries left untouched", originalsUntouched:"Original EXE/BAT/CMD files remain untouched.", everythingGood:"Everything looks good!", convertedCount:"Converted {0} Shortcut(s) to standard .lnk format.", shortcutsReady:"Your Shortcuts are ready.", checkingSavedChoices:"Checking your saved choices…", startingFresh:"Starting fresh…", clearingChoices:"Clearing your previous choices…", searchingBoth:"Searching Google Images, Yandex Images and the brand-icon catalog for square, high-resolution app Icons…", searchingGoogle:"Searching Google Images and brand Icons for square, high-resolution app Icons…", searchingYandex:"Searching Yandex Images and brand Icons for square, high-resolution app Icons…", onlineFound:"Found {0} candidate(s). Brand-relevant results are ranked first; resolution and square shape are tie-breakers. Choose one to Preview it, then Apply this Icon.", imageReady:"Image ready ({0} × {1}).{2} Preview the crop, then Apply.", imageQualityLow:" Low resolution may look soft at larger Icon sizes.", imageQualityHigh:" High enough for crisp Windows Icons.", imageLoaded:"Image loaded ({0} × {1}). Click Apply this Icon to use it.", imageDecodeError:"Could not decode that image. Try another image or save it locally first.", notImage:"That item is not an image. Drop the image itself, or copy the image and press Ctrl+V.", readingImage:"Reading image…", fileReadError:"Failed to read file.", tryingImageSource:"Trying image source {0} of {1}…", imageFetchError:"Could not fetch this image. Try dragging the image itself or using Copy image → Ctrl+V.", noImageUrl:"No usable image URL found. Copy the image itself or save it and choose it from your PC.", savingCustomIcon:"Saving custom Icon…", localServerError:"Error communicating with the local server.", readingDroppedImage:"Reading the dropped image…", dropReadError:"Could not read that drop. Drag the image itself, use Copy image → Ctrl+V, or save it and browse for the file."
  ,
    exeCount:"{0} EXE", scriptCount:"{0} BAT/CMD", existingShortcutCount:"{0} existing Shortcut(s)", preparedLauncherCount:"{0} Launcher URL(s) prepared as .lnk", romCount:"{0} emulator ROM(s)", linkedCount:"{0} already linked", launcherUtilityCount:"{0} Launcher utility Shortcut(s) left alone", helperSkippedCount:"{0} installer/helper file(s) skipped", failedUrlCount:"{0} URL conversion(s) kept as source files", safetyLimitCount:"safety limit: {0} extra entries left untouched", healthLauncherNote:"Launcher Shortcuts can be converted so their Icons can be customized.", healthBrokenNote:"Some Shortcuts point to a missing file; those items will be skipped safely.", scanPreparingPrograms:"Preparing your program Shortcuts…", scanSteamFolders:"Scanning SteamGridDB for your game folders…", scanSteamGames:"Scanning SteamGridDB for your games…", readingAppShortcuts:"Reading application Shortcuts…", readingFolders:"Reading your folders…", readingFolder:"Reading your folder…", backupItemCount:"{0} item(s) · {1}", backupPreviouslyRestored:"Previously restored: {0} · Can restore again", backupOriginalSaved:"Original Shortcut/Folder Icon state saved", repairScanned:"Shortcuts scanned: {0}", repairRepaired:"References repaired: {0}", repairRebuilt:"ICO files rebuilt from cache: {0}", repairAlreadyValid:"Already valid: {0}", repairUnresolved:"Unresolved: {0}", repairFailed:"Failed: {0}", repairCacheRefreshed:"Windows Icon Cache refreshed and Explorer restarted.", repairMissingArtwork:"Some Icons could not be rebuilt because matching Artwork is no longer in the local Cache.",
    previewUnavailable:"Preview unavailable from this host; try another result.", sizeUnknown:"size unknown", scanProgress:"Found {0} of {1}: {2}", scannedCounter:"{0} / {1} scanned", aboutSeconds:"about {0} second(s)", aboutMinutes:"about {0} minute(s)", scanEstimate:"{0} for {1} {2}.", programFileIconNoun:"program/file icon", gameSingular:"game", gamesPlural:"games", programSearchDetail:"Checking Google Images, Yandex Images and a structured brand-icon catalog; semantic relevance is prioritized over dimensions.", notAutoMatched:"no automatic match; left unchanged", savedSuffix:"saved", placeholderSuffix:"placeholder", placeholderLabel:"placeholder",
    loadingCover:"Loading…"
  },
  tr: {
    gettingReady:"Quick re-apply hazırlanıyor…", loadingSavedChoices:"Son klasörün ve kayıtlı seçimlerin yükleniyor.", checkingSavedBackups:"Kayıtlı Icon Backup'ları kontrol ediliyor.", restoringPreviousState:"Önceki Icon durumu geri yükleniyor…", reversingLatest:"En son kaydedilen Icon işlemi geri alınıyor.",     chooseRepairFolder:"Onarılacak klasörü seç…", repairFolderDetail:"Icon'ları beyaz veya bozuk görünen Game Library ya da Shortcut klasörünü seç.", repairingIcons:"Shortcut Icon'ları onarılıyor…", repairingDetail:"Kalıcı ICO dosyaları kontrol ediliyor, Cache içindeki Artwork ile yeniden oluşturulabilenler hazırlanıyor ve Windows Explorer yenileniyor.", selectFilesDetail:"Önde bir Windows penceresi açılacak. Güncellemek istediğin Shortcut'ları Ctrl+tıklayarak seç, ardından Open'a bas.", findingProgramIcons:"En uygun Program Icon'ları aranıyor…", scanningGames:"Oyunların taranıyor…", waitingForApply:"Gerçek indirme, Icon oluşturma, Backup ve uygulama işlemlerinden canlı ilerleme bekleniyor.", stopped:"Durduruldu", noSupportedFiles:"Desteklenen dosya veya Program Shortcut bulunamadı.", noGamesMatched:"Eşleştirilebilen oyun bulunamadı.",     programFilesScanning:"Program ve dosya Icon'ları bulunuyor…", readingFiles:"Seçtiğin dosyalar okunuyor…",
    applyPreparing:"Icon güncellemesi hazırlanıyor…", applyStarting:"Apply işlemi başlatılıyor…", applyComplete:"Bildirilen tüm işlemler tamamlandı.", applyFinishedDetail:"İşlem tamamlandı. Başarısız veya atlanan öğeleri aşağıdaki sonuçlardan incele.", progressConnectionLost:"Tarayıcı ile canlı ilerleme bağlantısı kesildi. Tamamlanmış olabilecek bir işlemi tekrarlamamak için yeniden denemeden önce CMD log'unu kontrol et.",
        invalidKey:"Bu API Key çalışmadı. Kontrol edip tekrar dene.", fileScanError:"Seçtiğin dosyalar okunamadı.", applyFailed:"Apply başarısız oldu.", standardShortcuts:"Standart Shortcut'lar", launcherShortcuts:"Launcher Shortcut'ları (.url)", brokenTargetLabel:"Bozuk / eksik hedef", launcherConversionNote:"Icon'ları özelleştirebilmek için Launcher Shortcut'ları dönüştürülebilir.", brokenTargetNote:"Bazı Shortcut'lar eksik dosyalara işaret ediyor; bu öğeler güvenli şekilde atlanacak.",     noPreviousFolder:"Quick re-apply için kullanılabilecek önceki bir klasör yok. Önce bir klasör tara.",
    noSavedChoices:"Yeniden uygulanabilecek kayıtlı seçim bulunamadı.",
    noUnusedRestore:"Henüz kullanılmamış Restore Point yok. Önce bir Icon değişikliği uygula.",
    undoConfirm:"{0} tarihli son Icon değişikliğini geri alalım mı? {1} öğeyi geri yükleyecek ve bu işlemde oluşturulan Shortcut'ları kaldıracak.",
    latestRestoreError:"Son Restore Point geri yüklenemedi.",
    backupListError:"Restore Point'ler okunamadı. Uygulama log'unu kontrol et.",
    historyEmpty:"Henüz History yok. Icon uyguladığında değişikliklerin burada görünecek.",
    backupSaveError:"Restore Point ayarı kaydedilemedi.",
    repairError:"Icon Repair işlemi tamamlanamadı.",
    repairRequestError:"Icon Repair isteği başarısız oldu.",
    pickerError:"Windows klasör seçici açılamadı.",
    lastFolderReady:"Son kullanılan klasör hazır. Scan'e bas veya başka bir yol seç/yapıştır.",
    noFolderChosen:"Klasör seçilmedi. Tekrar dene veya yukarıya bir yol yapıştır.",
    folderReady:"Klasör hazır. İşlem başlatılıyor…",
    invalidFolderPath:"Bu yol mevcut değil. Kontrol edip tekrar dene.",
    gameFolderScanError:"Game klasörü taranamadı.",
    gameFolderScanFailed:"Game klasörü taraması başarısız oldu.",
    scanFailed:"Scan başarısız oldu.",
    newGamesCount:"Son tamamlanan taramadan sonra {0} yeni dosya veya kısayol eklendi.",
    launcherCount:"{0} Launcher Shortcut bulundu{1}.",
    andShortcutCount:" ve {0} standart Shortcut",
    openingFolder:"Windows klasör seçici açılıyor…",
    findingGames:"Oyunlar ve Launcher'lar bulunuyor…",
    scanningFolder:"Bu klasördeki mevcut Shortcut'lar ve çalıştırılabilir oyun dosyaları taranıyor.",
    autoLoading:"Oyunlar ve Cover'lar otomatik seçiliyor",
    autoDetail:"Bir oyun eşleşmesinden emin olmadığımda senden onay isteyeceğim.",
    matchingProgress:"{1} oyundan {0} tanesi eşleştirildi.",
    checkingFolder:"Klasör kontrol ediliyor…",
    checkingShortcuts:"Shortcut'lar inceleniyor…",
    convertingShortcuts:"Shortcut'lar dönüştürülüyor…",
    convertingDetail:"Kısayollar çalışmaya devam edecek ve yeni Icon'ları gösterebilecek.",
    working:"İşleniyor…",
    loadingBackups:"Restore Point'ler yükleniyor…",
    readingBackups:"Kaydedilmiş Icon sürümleri okunuyor.",
    restoringIcons:"Önceki Icon'lar geri yükleniyor…",
    restoringDetail:"Kaydedilmiş Shortcut ve Folder durumu geri yükleniyor.",
    loadingHistory:"History yükleniyor…",
    checkingKey:"API Key kontrol ediliyor…",
    needKey:"Önce API Key'ini yapıştır.",
    clipboardError:"Clipboard okunamadı. Ctrl+V ile yapıştırıp Continue'a bas.",
    pasteKeyHint:"Kutucuğa Ctrl+V ile yapıştır, ardından Continue'a bas.",
    progressInterrupted:"İşlem ilerlemesi kesildi",
    checkStatus:"Durumu kontrol et",
    updateFailed:"Güncelleme tamamlanamadı.",
    checkLog:"Uygulama log'unu kontrol edip tekrar dene.",
    updateStopped:"İşlem güvenli şekilde durduruldu",
    noIconsChanged:"Hiçbir Icon değiştirilmedi",
    restorePointFailed:"Restore Point oluşturulamadı. Bu nedenle hiçbir Shortcut değiştirilmeden işlem durduruldu.",
    complete:"Tamamlandı",
    finishedIssues:"Bazı sorunlarla tamamlandı",
    shelfReady:"Tamamlandı! Oyun klasörün hazır.",
    progressLive:"Canlı ilerleme bir zamanlayıcıya değil, tamamlanan gerçek işlemlere dayanır.",
    noArtCandidates:"Henüz Online aday yok. İki kaynaktan da daha fazla sonuç ara, bir Search sekmesi aç veya görseli Preview alanına sürükle/yapıştır.",
    onlineLoading:"Otomatik aday bulunamadı. Google Images ve Yandex Images aranıyor…",
    onlineNoResults:"Doğrudan görsel sonucu alınamadı. Google/Yandex sekmelerini açabilir veya görseli Preview alanına bırakabilirsin.",
    onlineFailed:"Online sonuçlar alınamadı. Google/Yandex'i sekmede aç veya görseli Preview alanına sürükle.",
    loadingPreview:"Seçilen görsel 1:1 Preview alanına yükleniyor…",
    useImage:"Bu görseli kullan",
    candidate:"Aday",
    quality:"kalite",
    nearSquare:"kareye yakın",
    notSquare:"kare değil",
    launchableEntries:"çalıştırılabilir öğe bulundu", exeFiles:"EXE", scriptFiles:"BAT/CMD", existingLinks:"mevcut Shortcut", urlPrepared:".lnk olarak hazırlanan Launcher URL", romFiles:"emulator ROM", alreadyLinked:"zaten çalışan Shortcut'a sahip", launcherUtilities:"olduğu gibi bırakılan Launcher yardımcı Shortcut'ı", installerHelpers:"atlanan kurulum/yardımcı dosya", urlsKept:"kaynak olarak bırakılan URL dönüşümü", safetyLimit:"güvenlik sınırı", extraEntries:"dokunulmadan bırakılan ek öğe", originalsUntouched:"Orijinal EXE/BAT/CMD dosyalarına dokunulmadı.", everythingGood:"Her şey yolunda görünüyor!", convertedCount:"{0} Shortcut standart .lnk formatına dönüştürüldü.", shortcutsReady:"Shortcut'ların hazır.", checkingSavedChoices:"Kayıtlı seçimlerin kontrol ediliyor…", startingFresh:"Sıfırdan başlanıyor…", clearingChoices:"Önceki seçimlerin temizleniyor…", searchingBoth:"Kare ve yüksek çözünürlüklü app Icon'ları için Google Images, Yandex Images ve brand-icon kataloğu aranıyor…", searchingGoogle:"Kare ve yüksek çözünürlüklü app Icon'ları için Google Images ve brand Icon'ları aranıyor…", searchingYandex:"Kare ve yüksek çözünürlüklü app Icon'ları için Yandex Images ve brand Icon'ları aranıyor…", onlineFound:"{0} aday bulundu. Önce brand ile alakalı sonuçlar sıralanır; çözünürlük ve kare oranı sonraki ölçütlerdir. Birini Preview edip Apply edebilirsin.", imageReady:"Görsel hazır ({0} × {1}).{2} Crop'u Preview edip Apply edebilirsin.", imageQualityLow:" Büyük Icon boyutlarında düşük çözünürlük bulanık görünebilir.", imageQualityHigh:" Net Windows Icon'ları için yeterli çözünürlük.", imageLoaded:"Görsel yüklendi ({0} × {1}). Kullanmak için Apply this Icon'a bas.", imageDecodeError:"Görsel çözümlenemedi. Başka bir görsel dene veya önce bilgisayarına kaydet.", notImage:"Bu öğe bir görsel değil. Görselin kendisini bırak veya Copy image ile kopyalayıp Ctrl+V yap.", readingImage:"Görsel okunuyor…", fileReadError:"Dosya okunamadı.", tryingImageSource:"Görsel kaynağı deneniyor: {0} / {1}…", imageFetchError:"Bu görsel alınamadı. Görselin kendisini sürükle veya Copy image → Ctrl+V kullan.", noImageUrl:"Kullanılabilir bir Image URL bulunamadı. Görseli kopyala veya bilgisayarına kaydedip seç.", savingCustomIcon:"Custom Icon kaydediliyor…", localServerError:"Yerel sunucuyla iletişim kurulamadı.", readingDroppedImage:"Bırakılan görsel okunuyor…", dropReadError:"Bırakılan görsel okunamadı. Görselin kendisini sürükle, Copy image → Ctrl+V kullan veya dosyayı kaydedip seç."
  ,
    exeCount:"{0} EXE", scriptCount:"{0} BAT/CMD", existingShortcutCount:"{0} mevcut Shortcut", preparedLauncherCount:"{0} Launcher URL .lnk olarak hazırlandı", romCount:"{0} emulator ROM", linkedCount:"{0} zaten bir Shortcut'a bağlı", launcherUtilityCount:"{0} Launcher yardımcı Shortcut'ı olduğu gibi bırakıldı", helperSkippedCount:"{0} kurulum/yardımcı dosya atlandı", failedUrlCount:"{0} URL dönüşümü kaynak dosya olarak bırakıldı", safetyLimitCount:"güvenlik sınırı: {0} ek öğeye dokunulmadı", healthLauncherNote:"Icon'larını özelleştirmek için Launcher Shortcut'ları dönüştürülebilir.", healthBrokenNote:"Bazı Shortcut'lar eksik dosyalara işaret ediyor; bu öğeler güvenli şekilde atlanacak.", scanPreparingPrograms:"Program Shortcut'ları hazırlanıyor…", scanSteamFolders:"Game klasörlerin SteamGridDB'de aranıyor…", scanSteamGames:"Oyunların SteamGridDB'de aranıyor…", readingAppShortcuts:"Uygulama Shortcut'ları okunuyor…", readingFolders:"Klasörlerin okunuyor…", readingFolder:"Klasörün okunuyor…", backupItemCount:"{0} öğe · {1}", backupPreviouslyRestored:"Daha önce Restore edildi: {0} · Yeniden Restore edilebilir", backupOriginalSaved:"Orijinal Shortcut/Folder Icon durumu kaydedildi", repairScanned:"Taranan Shortcut: {0}", repairRepaired:"Onarılan referans: {0}", repairRebuilt:"Cache'ten yeniden oluşturulan ICO: {0}", repairAlreadyValid:"Zaten geçerli: {0}", repairUnresolved:"Çözümlenemedi: {0}", repairFailed:"Başarısız: {0}", repairCacheRefreshed:"Windows Icon Cache yenilendi ve Explorer yeniden başlatıldı.", repairMissingArtwork:"Eşleşen Artwork yerel Cache'te bulunmadığından bazı Icon'lar yeniden oluşturulamadı.",
    previewUnavailable:"Bu kaynaktan Preview alınamadı; başka bir sonuç dene.", sizeUnknown:"boyut bilinmiyor", scanProgress:"{1} öğeden {0} bulundu: {2}", scannedCounter:"{0} / {1} tarandı", aboutSeconds:"yaklaşık {0} saniye", aboutMinutes:"yaklaşık {0} dakika", scanEstimate:"Tahmini süre: {0} · {1} {2}.", programFileIconNoun:"Program/Dosya Icon'u", gameSingular:"oyun", gamesPlural:"oyun", programSearchDetail:"Google Images, Yandex Images ve yapılandırılmış brand-icon kataloğu kontrol ediliyor; boyuttan önce anlamsal uygunluk dikkate alınıyor.", notAutoMatched:"otomatik eşleşme bulunamadı; değişiklik yapılmadı", savedSuffix:"kayıtlı", placeholderSuffix:"placeholder", placeholderLabel:"placeholder",
    loadingCover:"Yükleniyor…"
  },
  ar: {
    gettingReady:"جارٍ التحضير لإعادة التطبيق…", loadingSavedChoices:"جارٍ تحميل المجلد السابق والاختيارات المحفوظة.", checkingSavedBackups:"جارٍ فحص نسخ الأيقونات الاحتياطية المحفوظة.", restoringPreviousState:"جارٍ استعادة حالة الأيقونات السابقة…", reversingLatest:"جارٍ التراجع عن أحدث عملية أيقونات محفوظة.",     chooseRepairFolder:"اختر مجلداً لإصلاحه…", repairFolderDetail:"اختر Game Library أو مجلد Shortcuts الذي تظهر أيقوناته بيضاء أو تالفة.", repairingIcons:"جارٍ إصلاح أيقونات الاختصارات…", repairingDetail:"جارٍ فحص ملفات ICO الدائمة وإعادة إنشاء الأيقونات من Artwork المخزّنة عند توفرها ثم تحديث Windows Explorer.", selectFilesDetail:"ستظهر نافذة Windows في المقدمة. حدّد الاختصارات المطلوبة باستخدام Ctrl ثم اضغط Open.", findingProgramIcons:"جارٍ العثور على أفضل أيقونات البرامج…", scanningGames:"جارٍ فحص الألعاب…", waitingForApply:"بانتظار تقدم مباشر من عمليات التنزيل وإنشاء الأيقونات والنسخ الاحتياطي والتطبيق الفعلية.", stopped:"متوقف", noSupportedFiles:"لم يتم العثور على ملفات مدعومة أو اختصارات برامج.", noGamesMatched:"لم يتم العثور على ألعاب قابلة للمطابقة.",     programFilesScanning:"جارٍ العثور على أيقونات البرامج والملفات…", readingFiles:"جارٍ قراءة الملفات التي اخترتها…",
    applyPreparing:"جارٍ تجهيز تحديث الأيقونات…", applyStarting:"جارٍ بدء عملية التطبيق…", applyComplete:"اكتملت جميع العمليات المبلغ عنها.", applyFinishedDetail:"اكتملت العملية. راجع النتائج أدناه للعناصر التي فشلت أو تم تخطيها.", progressConnectionLost:"انقطع الاتصال المباشر بين المتصفح والتقدم. تحقق من سجل CMD قبل إعادة المحاولة لتجنب تكرار عملية ربما اكتملت بالفعل.",
        invalidKey:"لم يعمل API Key هذا. تحقق منه وحاول مرة أخرى.", fileScanError:"تعذرت قراءة الملفات التي اخترتها.", applyFailed:"فشل Apply.", standardShortcuts:"الاختصارات القياسية", launcherShortcuts:"اختصارات Launcher (.url)", brokenTargetLabel:"هدف تالف / مفقود", launcherConversionNote:"يمكن تحويل اختصارات Launcher لتتمكن من تخصيص أيقوناتها.", brokenTargetNote:"تشير بعض الاختصارات إلى ملفات مفقودة؛ سيتم تخطي هذه العناصر بأمان.",     noPreviousFolder:"لا يوجد مجلد سابق لإعادة التطبيق عليه. افحص مجلداً أولاً.",
    noSavedChoices:"لا توجد اختيارات محفوظة لإعادة تطبيقها.",
    noUnusedRestore:"لا توجد Restore Point غير مستخدمة. طبّق تغييراً للأيقونات أولاً لإنشاء Backup.",
    undoConfirm:"هل تريد التراجع عن أحدث تغيير للأيقونات بتاريخ {0}؟ سيستعيد {1} عنصراً ويحذف الاختصارات التي أنشأها هذا التغيير.",
    latestRestoreError:"تعذرت استعادة أحدث Restore Point.",
    backupListError:"تعذرت قراءة Restore Points. تحقق من سجل التطبيق.",
    historyEmpty:"لا يوجد History بعد. ستظهر تغييراتك هنا بعد تطبيق الأيقونات.",
    backupSaveError:"تعذر حفظ إعداد Restore Point.",
    repairError:"تعذر إكمال عملية Icon Repair.",
    repairRequestError:"فشل طلب Icon Repair.",
    pickerError:"تعذر فتح نافذة اختيار مجلدات Windows.",
    lastFolderReady:"المجلد المستخدم سابقاً جاهز. اضغط Scan أو اختر مساراً آخر.",
    noFolderChosen:"لم يتم اختيار مجلد. حاول مرة أخرى أو الصق المسار أعلاه.",
    folderReady:"المجلد جاهز. جارٍ البدء…",
    invalidFolderPath:"هذا المسار غير موجود. تحقق منه وحاول مرة أخرى.",
    gameFolderScanError:"تعذر فحص مجلد اللعبة.",
    gameFolderScanFailed:"فشل فحص مجلد اللعبة.",
    scanFailed:"فشل Scan.",
    newGamesCount:"تمت إضافة {0} من الملفات أو الاختصارات منذ آخر فحص مكتمل.",
    launcherCount:"تم العثور على {0} من اختصارات Launcher{1}.",
    andShortcutCount:" و{0} من الاختصارات القياسية",
    openingFolder:"جارٍ فتح نافذة مجلدات Windows…",
    findingGames:"جارٍ العثور على الألعاب وروابط Launcher…",
    scanningFolder:"جارٍ فحص الاختصارات وملفات الألعاب القابلة للتشغيل في هذا المجلد.",
    autoLoading:"جارٍ اختيار الألعاب والأغلفة تلقائياً",
    autoDetail:"سأتوقف لطلب التأكيد فقط عندما لا أكون واثقاً من مطابقة اللعبة.",
    matchingProgress:"تمت مطابقة {0} من أصل {1}.",
    checkingFolder:"جارٍ فحص المجلد…",
    checkingShortcuts:"جارٍ فحص الاختصارات…",
    convertingShortcuts:"جارٍ تحويل الاختصارات…",
    convertingDetail:"ستستمر الاختصارات في العمل وستتمكن من عرض الأيقونات الجديدة.",
    working:"جارٍ العمل…",
    loadingBackups:"جارٍ تحميل Restore Points…",
    readingBackups:"جارٍ قراءة إصدارات الأيقونات المحفوظة.",
    restoringIcons:"جارٍ استعادة الأيقونات السابقة…",
    restoringDetail:"جارٍ استعادة حالة الاختصارات والمجلدات المحفوظة.",
    loadingHistory:"جارٍ تحميل History…",
    checkingKey:"جارٍ التحقق من API Key…",
    needKey:"الصق API Key أولاً.",
    clipboardError:"تعذرت قراءة الحافظة. الصق باستخدام Ctrl+V ثم اضغط Continue.",
    pasteKeyHint:"الصق باستخدام Ctrl+V في المربع ثم اضغط Continue.",
    progressInterrupted:"انقطع تدفق التقدم",
    checkStatus:"تحقق من الحالة",
    updateFailed:"تعذر إكمال التحديث.",
    checkLog:"تحقق من سجل التطبيق وحاول مرة أخرى.",
    updateStopped:"تم إيقاف العملية بأمان",
    noIconsChanged:"لم يتم تغيير أيقونات",
    restorePointFailed:"تعذر إنشاء Restore Point، لذلك توقف التطبيق قبل تغيير أي اختصار.",
    complete:"اكتمل",
    finishedIssues:"اكتمل مع بعض المشكلات",
    shelfReady:"تم! مكتبة الألعاب جاهزة.",
    progressLive:"يعتمد التقدم المباشر على العمليات المكتملة فعلياً، وليس على مؤقت.",
    noArtCandidates:"لا توجد نتائج Online مضمّنة بعد. ابحث من المصدرين أو افتح تبويب بحث أو اسحب صورة إلى Preview.",
    onlineLoading:"لا توجد اقتراحات تلقائية بعد. جارٍ البحث في Google Images وYandex Images…",
    onlineNoResults:"تعذر استخراج صور مباشرة. يمكنك فتح Google/Yandex أو سحب صورة إلى Preview.",
    onlineFailed:"تعذر جلب نتائج Online. افتح Google/Yandex أو اسحب صورة إلى Preview.",
    loadingPreview:"جارٍ تحميل الصورة المختارة إلى Preview بنسبة 1:1…",
    useImage:"استخدم هذه الصورة",
    candidate:"نتيجة",
    quality:"الجودة",
    nearSquare:"قريب من المربع",
    notSquare:"ليس مربعاً",
    launchableEntries:"عناصر قابلة للتشغيل تم العثور عليها", exeFiles:"EXE", scriptFiles:"BAT/CMD", existingLinks:"اختصارات موجودة", urlPrepared:"روابط Launcher مجهزة كملفات .lnk", romFiles:"ملفات ROM للمحاكيات", alreadyLinked:"لديها اختصار يعمل بالفعل", launcherUtilities:"اختصارات أدوات Launcher التي تُركت دون تغيير", installerHelpers:"ملفات تثبيت/مساعدة تم تخطيها", urlsKept:"تحويلات URL التي احتُفظت كملفات مصدر", safetyLimit:"حد الأمان", extraEntries:"عناصر إضافية تُركت دون تغيير", originalsUntouched:"لم يتم تعديل ملفات EXE/BAT/CMD الأصلية.", everythingGood:"كل شيء يبدو جيداً!", convertedCount:"تم تحويل {0} من الاختصارات إلى تنسيق .lnk القياسي.", shortcutsReady:"اختصاراتك جاهزة.", checkingSavedChoices:"جارٍ التحقق من اختياراتك المحفوظة…", startingFresh:"جارٍ البدء من جديد…", clearingChoices:"جارٍ مسح اختياراتك السابقة…", searchingBoth:"جارٍ البحث في Google Images وYandex Images وكتالوج الأيقونات عن أيقونات تطبيقات مربعة وعالية الدقة…", searchingGoogle:"جارٍ البحث في Google Images وكتالوج العلامات عن أيقونات تطبيقات مربعة وعالية الدقة…", searchingYandex:"جارٍ البحث في Yandex Images وكتالوج العلامات عن أيقونات تطبيقات مربعة وعالية الدقة…", onlineFound:"تم العثور على {0} نتيجة. تظهر النتائج المرتبطة بالعلامة أولاً؛ ثم تُستخدم الدقة والشكل المربع لترتيبها. اختر نتيجة لمعاينتها ثم Apply.", imageReady:"الصورة جاهزة ({0} × {1}).{2} راجع Crop في Preview ثم اضغط Apply.", imageQualityLow:" قد تبدو الدقة المنخفضة ضبابية عند أحجام الأيقونات الكبيرة.", imageQualityHigh:" الدقة كافية لأيقونات Windows واضحة.", imageLoaded:"تم تحميل الصورة ({0} × {1}). اضغط Apply this Icon لاستخدامها.", imageDecodeError:"تعذر فك ترميز الصورة. جرّب صورة أخرى أو احفظها محلياً أولاً.", notImage:"هذا العنصر ليس صورة. أسقط الصورة نفسها أو انسخها باستخدام Copy image ثم اضغط Ctrl+V.", readingImage:"جارٍ قراءة الصورة…", fileReadError:"فشلت قراءة الملف.", tryingImageSource:"جارٍ تجربة مصدر الصورة {0} من {1}…", imageFetchError:"تعذر جلب هذه الصورة. اسحب الصورة نفسها أو استخدم Copy image → Ctrl+V.", noImageUrl:"لم يتم العثور على Image URL صالح. انسخ الصورة نفسها أو احفظها واخترها من جهازك.", savingCustomIcon:"جارٍ حفظ Custom Icon…", localServerError:"خطأ في الاتصال بالخادم المحلي.", readingDroppedImage:"جارٍ قراءة الصورة التي تم إسقاطها…", dropReadError:"تعذرت قراءة الصورة. اسحب الصورة نفسها أو استخدم Copy image → Ctrl+V أو احفظها واختر الملف."
 ,
    exeCount:"{0} EXE", scriptCount:"{0} BAT/CMD", existingShortcutCount:"{0} اختصار موجود", preparedLauncherCount:"تم تجهيز {0} من روابط Launcher كملفات .lnk", romCount:"{0} من ملفات ROM للمحاكيات", linkedCount:"{0} لديها اختصار بالفعل", launcherUtilityCount:"تم ترك {0} من اختصارات أدوات Launcher دون تغيير", helperSkippedCount:"تم تخطي {0} من ملفات التثبيت/المساعدة", failedUrlCount:"تم الاحتفاظ بـ {0} من تحويلات URL كملفات مصدر", safetyLimitCount:"حد الأمان: تُركت {0} من العناصر الإضافية دون تغيير", healthLauncherNote:"يمكن تحويل اختصارات Launcher لتخصيص أيقوناتها.", healthBrokenNote:"تشير بعض الاختصارات إلى ملفات مفقودة؛ سيتم تخطيها بأمان.", scanPreparingPrograms:"جارٍ تجهيز اختصارات البرامج…", scanSteamFolders:"جارٍ البحث عن مجلدات الألعاب في SteamGridDB…", scanSteamGames:"جارٍ البحث عن ألعابك في SteamGridDB…", readingAppShortcuts:"جارٍ قراءة اختصارات التطبيقات…", readingFolders:"جارٍ قراءة المجلدات…", readingFolder:"جارٍ قراءة المجلد…", backupItemCount:"{0} عنصر · {1}", backupPreviouslyRestored:"تمت الاستعادة سابقاً: {0} · يمكن الاستعادة مرة أخرى", backupOriginalSaved:"تم حفظ حالة أيقونات الاختصارات/المجلدات الأصلية", repairScanned:"الاختصارات التي تم فحصها: {0}", repairRepaired:"المراجع التي تم إصلاحها: {0}", repairRebuilt:"ملفات ICO التي أُعيد إنشاؤها من Cache: {0}", repairAlreadyValid:"صالحة بالفعل: {0}", repairUnresolved:"لم يتم حلها: {0}", repairFailed:"فشل: {0}", repairCacheRefreshed:"تم تحديث Windows Icon Cache وإعادة تشغيل Explorer.", repairMissingArtwork:"تعذر إعادة إنشاء بعض الأيقونات لأن Artwork المطابق لم يعد موجوداً في Cache المحلي.",
    previewUnavailable:"المعاينة غير متاحة من هذا المصدر؛ جرّب نتيجة أخرى.", sizeUnknown:"الحجم غير معروف", scanProgress:"تم العثور على {0} من أصل {1}: {2}", scannedCounter:"تم فحص {0} / {1}", aboutSeconds:"حوالي {0} ثانية", aboutMinutes:"حوالي {0} دقيقة", scanEstimate:"الوقت التقديري: {0} · {1} {2}.", programFileIconNoun:"أيقونة برنامج/ملف", gameSingular:"لعبة", gamesPlural:"ألعاب", programSearchDetail:"جارٍ فحص Google Images وYandex Images وكتالوج أيقونات العلامات؛ تُعطى الأولوية للصلة الدلالية قبل الأبعاد.", notAutoMatched:"لم يتم العثور على مطابقة تلقائية؛ تُرك دون تغيير", savedSuffix:"محفوظ", placeholderSuffix:"Placeholder", placeholderLabel:"Placeholder",
    loadingCover:"جارٍ التحميل…"
  }
};
function statusText(key) {
  var locale = statusI18n[currentLang] || statusI18n.en;
  return locale[key] || statusI18n.en[key] || key;
}

var manualGameI18n = {
  en: {
    heading:"Choose a different game", placeholder:"Search another game by title…",
    searchButton:"Search SteamGridDB", customButton:"Use a custom title + choose cover",
    prompt:"Choose an existing match, search SteamGridDB, or enter a custom title.",
    initialMatches:"Automatic alternatives are shown below. Search for more titles above.",
    searching:"Searching SteamGridDB…", noResults:"No games found. Try another title or use a custom title.",
    needKey:"A SteamGridDB API Key is required for catalogue search. You can still use a custom title and external cover.",
    failed:"Game search failed. Check the SteamGridDB API Key and try again.", changeGame:"Change Game"
  },
  tr: {
    heading:"Farklı bir oyun seç", placeholder:"Başka bir oyunu adıyla ara…",
    searchButton:"SteamGridDB'de ara", customButton:"Özel oyun adı belirle + kapak seç",
    prompt:"Mevcut eşleşmelerden birini seç, SteamGridDB'de ara veya özel bir oyun adı gir.",
    initialMatches:"Otomatik alternatifler aşağıda. Daha fazla oyun bulmak için yukarıdan ara.",
    searching:"SteamGridDB aranıyor…", noResults:"Oyun bulunamadı. Başka bir ad dene veya özel oyun adı kullan.",
    needKey:"Katalog araması için SteamGridDB API Key gerekli. Yine de özel oyun adı ve harici kapak kullanabilirsin.",
    failed:"Oyun araması başarısız. SteamGridDB API Key'i kontrol edip tekrar dene.", changeGame:"Oyunu Değiştir"
  },
  ar: {
    heading:"اختر لعبة مختلفة", placeholder:"ابحث عن لعبة أخرى بالاسم…",
    searchButton:"ابحث في SteamGridDB", customButton:"استخدم اسماً مخصصاً واختر الغلاف",
    prompt:"اختر تطابقاً موجوداً أو ابحث في SteamGridDB أو أدخل اسم لعبة مخصصاً.",
    initialMatches:"تظهر البدائل التلقائية أدناه. ابحث عن عناوين أخرى من الأعلى.",
    searching:"جارٍ البحث في SteamGridDB…", noResults:"لم يتم العثور على ألعاب. جرّب اسماً آخر أو استخدم اسماً مخصصاً.",
    needKey:"يلزم SteamGridDB API Key للبحث في الكتالوج. يمكنك استخدام اسم مخصص وغلاف خارجي.",
    failed:"فشل البحث عن اللعبة. تحقق من SteamGridDB API Key ثم حاول مجدداً.", changeGame:"تغيير اللعبة"
  }
};
function manualGameText(key) {
  var locale = manualGameI18n[currentLang] || manualGameI18n.en;
  return locale[key] || manualGameI18n.en[key] || key;
}

var currentLang = 'en';

function formatStr(str, args) {
  return str.replace(/{(\d+)}/g, function(match, number) {
    return typeof args[number] != 'undefined' ? args[number] : match;
  });
}

function itemNoun(plural){
  var t = i18n[currentLang] || i18n['en'];
  if (isFolderMode()) return plural ? t.nounFolders : t.nounFolder;
  return plural ? t.nounShortcuts : t.nounShortcut;
}
function itemNounCap(plural){
  // Capitalization is mostly for English, we can just reuse the noun function and capitalize the first letter.
  var noun = itemNoun(plural);
  return noun.charAt(0).toUpperCase() + noun.slice(1);
}

function setLang(lang) {
  if (['en','tr','ar'].indexOf(lang) < 0) return;
  currentLang = lang;
  try { localStorage.setItem('gis-lang-v3', currentLang); } catch(e){}
  applyLang();
}

function toggleLang() {
  // Kept as a keyboard/accessibility fallback; the visible control is the 3-language flag switcher.
  setLang(currentLang === 'en' ? 'tr' : (currentLang === 'tr' ? 'ar' : 'en'));
}

function applyLang() {
  document.documentElement.setAttribute('dir', currentLang === 'ar' ? 'rtl' : 'ltr');
  document.documentElement.setAttribute('lang', currentLang);

  var t = i18n[currentLang] || i18n.en;
  var screen = screenI18n[currentLang] || screenI18n.en;
  var el = function(id) { return document.getElementById(id); };

  var languageSwitcher = el('languageSwitcher');
  if (languageSwitcher) {
    languageSwitcher.setAttribute('dir','ltr');
    languageSwitcher.setAttribute('aria-label', currentLang === 'ar' ? 'اختيار اللغة' : (currentLang === 'tr' ? 'Dil seçimi' : 'Language selection'));
  }
  var nextLanguageName = currentLang === 'en' ? 'Turkish' : (currentLang === 'tr' ? 'Arabic' : 'English');
  var currentLanguageName = currentLang === 'en' ? 'English' : (currentLang === 'tr' ? 'Türkçe' : 'العربية');
  document.querySelectorAll('.lang-option').forEach(function(button) {
    var active = button.getAttribute('data-lang') === currentLang;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', active ? 'true' : 'false');
    if (active) {
      button.title = 'Switch to ' + nextLanguageName;
      button.setAttribute('aria-label', currentLanguageName + '. Switch to ' + nextLanguageName + '.');
    }
  });

  var homeHeroP = document.querySelector('.home-hero p');
  if(homeHeroP) homeHeroP.textContent = t.homeSubtitle;

  var homeBtns = document.querySelectorAll('.home-btn');
  if(homeBtns.length >= 5) {
    homeBtns[0].querySelector('.t').textContent = t.btnShortcuts;
    homeBtns[0].querySelector('.d').textContent = t.descShortcuts;
    homeBtns[1].querySelector('.t').textContent = t.btnAllFolders;
    homeBtns[1].querySelector('.d').textContent = t.descAllFolders;
    homeBtns[2].querySelector('.t').textContent = t.btnSingleFolder;
    homeBtns[2].querySelector('.d').textContent = t.descSingleFolder;
    homeBtns[3].querySelector('.t').textContent = t.btnSpecific;
    homeBtns[3].querySelector('.d').textContent = t.descSpecific;
    homeBtns[4].querySelector('.t').textContent = t.btnRepair;
    homeBtns[4].querySelector('.d').textContent = t.descRepair;
    if (homeBtns.length >= 6) {
      homeBtns[5].querySelector('.t').textContent = t.btnProgramIcons;
      homeBtns[5].querySelector('.d').textContent = t.descProgramIcons;
    }
    if (homeBtns.length >= 7) {
      homeBtns[6].querySelector('.t').textContent = t.btnAnyFiles || i18n.en.btnAnyFiles;
      homeBtns[6].querySelector('.d').textContent = t.descAnyFiles || i18n.en.descAnyFiles;
    }
    if (homeBtns.length >= 8) {
      homeBtns[7].querySelector('.t').textContent = t.btnShortcutsOnly || i18n.en.btnShortcutsOnly;
      homeBtns[7].querySelector('.d').textContent = t.descShortcutsOnly || i18n.en.descShortcutsOnly;
    }
  }

  var toolBtns = document.querySelectorAll('.tool-btn');
  if(toolBtns.length >= 4) {
    toolBtns[0].textContent = t.btnQuick;
    toolBtns[1].textContent = t.btnUndoLast || i18n.en.btnUndoLast;
    toolBtns[2].textContent = t.btnHistory;
    toolBtns[3].textContent = t.btnUndo;
  }
  if (el('chooseLocalImageBtn')) el('chooseLocalImageBtn').textContent = '📁 ' + t.chooseLocalImage;
  if (el('backupTitle')) el('backupTitle').textContent = t.backupTitle;
  if (el('backupSubtitle')) el('backupSubtitle').textContent = t.backupSubtitle;
  if (el('backupRetentionLabel')) el('backupRetentionLabel').textContent = t.backupRetentionLabel;
  many('#backupRetention option', screen.retentionOptions);
  if (el('backupRefreshBtn')) el('backupRefreshBtn').textContent = screen.refresh || 'Refresh';

  if (typeof updateFolderScreenLabels === 'function') updateFolderScreenLabels();

  var aBanner = el('autoBanner'); if(aBanner) aBanner.innerHTML = t.autoBannerText;
  var urlIn = el('customUrlInput'); if(urlIn) urlIn.setAttribute('placeholder', t.urlPlaceholder);
  var bhBtn = document.querySelector('#step-report button[onclick="goHome()"]');
  if(bhBtn) bhBtn.textContent = t.btnBackHome;

  var stepSpans = document.querySelectorAll('.step-labels span');
  if (stepSpans.length >= 4) {
    stepSpans[0].textContent = t.stepFolder;
    stepSpans[1].textContent = t.stepMatch;
    stepSpans[2].textContent = t.stepReview;
    stepSpans[3].textContent = t.stepDone;
  }

  if(el('confirmTitle')) el('confirmTitle').textContent = (typeof state !== 'undefined' && state.autoAll) ? t.confirmAutoTitle : t.confirmTitle;
  var confHint = document.querySelector('#step-confirm .hint');
  if(confHint) confHint.textContent = t.highestConfidence;
  var cBtns = document.querySelectorAll('#confirmBtns button');
  if (cBtns.length >= 4) {
    cBtns[0].textContent = t.btnLooksGood;
    cBtns[1].textContent = t.btnDiffCover;
    cBtns[2].textContent = (typeof state !== 'undefined' && state.iconSearchOnly) ? (screenI18n[currentLang] || screenI18n.en).altIconMatch : t.btnWrongGame;
    cBtns[3].textContent = t.googleSearchBtn;
  }
  var autoBtn = document.querySelector('.auto-btn');
  if(autoBtn) autoBtn.textContent = t.btnAutoAll;

  document.querySelectorAll('.rtg').forEach(function(b) { b.textContent = t.btnReturnGrid; });

  var mH2 = document.querySelector('#step-matches h2');
  if(mH2) mH2.textContent = (typeof state !== 'undefined' && state.iconSearchOnly) ? (screen.altIconTitle || t.titleMatches) : manualGameText('heading');
  if (el('gameSearchInput')) el('gameSearchInput').placeholder = manualGameText('placeholder');
  if (el('gameSearchButton')) el('gameSearchButton').textContent = manualGameText('searchButton');
  if (el('useCustomGameTitleButton')) el('useCustomGameTitleButton').textContent = manualGameText('customButton');
  document.querySelectorAll('.review-change-game').forEach(function(button){ button.textContent = manualGameText('changeGame'); });
  var aH2 = document.querySelector('#step-artwork h2'); if(aH2) aH2.textContent = t.titleArtwork;
  var rH2 = document.querySelector('#step-review h2'); if(rH2) rH2.textContent = t.titleReview;
  var rSub = document.querySelector('#step-review .sub'); if(rSub) rSub.textContent = t.subReview;

  if(el('reviewSearch')) el('reviewSearch').setAttribute('placeholder', t.searchReview);
  if(el('finishBtn')) el('finishBtn').textContent = t.btnFinishApply;
  if(el('changeBtn') && typeof updateChangeBtn === 'function') updateChangeBtn();
  var startOver = document.querySelector('#reviewBtns .g-bad');
  if(startOver) startOver.textContent = t.btnStartOver;

  var repH2 = document.querySelector('#step-report h2'); if(repH2) repH2.textContent = t.reportTitle;
  var repSub = document.querySelector('#step-report .sub'); if(repSub) repSub.textContent = t.reportSub;
  var repBtns = document.querySelectorAll('#reportBtns button');
  if (repBtns.length >= 2) {
    repBtns[0].textContent = t.btnFinishOpen;
    repBtns[1].textContent = t.btnReturnReview;
  }

  var gBtn = el('googleImagesBtn');
  if(gBtn) gBtn.textContent = t.googleSearchBtn;
  var yBtn = el('yandexImagesBtn');
  if(yBtn) yBtn.textContent = t.yandexSearchBtn;
  if(el('customTitle')) el('customTitle').textContent = t.customTitle;
  if(el('customKindGame')) el('customKindGame').textContent = t.kindGame;
  if(el('customKindProgram')) el('customKindProgram').textContent = t.kindProgram;
  if(el('customSearchHint')) el('customSearchHint').textContent = t.customSearchHint;
  if(el('customApplyBtn')) el('customApplyBtn').textContent = '✓ ' + t.customApplyBtn;
  if(el('customSkipBtn')) el('customSkipBtn').textContent = '← ' + t.customSkipBtn;
  if (typeof updateCustomSearchKindUi === 'function') updateCustomSearchKindUi();
  var dropTxt = document.querySelector('#customDropZone > div:nth-child(2)');
  if(dropTxt) dropTxt.innerHTML = t.dragDropText.replace('Ctrl+V', '<kbd style="background:var(--panel);padding:2px 7px;border-radius:6px;border:1px solid var(--line);">Ctrl+V</kbd>');

  // Ready to Apply Screen
  var confirmApplyCard = document.getElementById('step-confirm-apply');
  if(confirmApplyCard) {
    var h2 = confirmApplyCard.querySelector('h2');
    if(h2) h2.textContent = t.applyTitle;
    var subs = confirmApplyCard.querySelectorAll('.sub');
    if(subs.length > 1) subs[1].textContent = t.applySub;
    var applyBtns = confirmApplyCard.querySelectorAll('.btn-row button');
    if(applyBtns.length >= 2) {
      applyBtns[0].textContent = t.btnYesApply;
      applyBtns[1].textContent = t.btnGoBack;
    }
  }

  // Welcome Back (Memory) Screen
  var memoryCard = document.getElementById('step-memory');
  if(memoryCard) {
    var mh2 = memoryCard.querySelector('h2');
    if(mh2) mh2.textContent = t.memoryTitle;
    var msubs = memoryCard.querySelectorAll('.sub');
    if(msubs.length > 1) msubs[1].textContent = t.memorySub;
    var memBtns = memoryCard.querySelectorAll('.btn-row button');
    if(memBtns.length >= 2) {
      memBtns[0].textContent = t.btnUseMemory;
      memBtns[1].textContent = t.btnStartOverMemory;
    }
  }

  document.querySelectorAll('.back-btn').forEach(function(b) {
    if (b.textContent.includes('Back') || b.textContent.includes('Geri') || b.textContent.includes('رجوع')) {
      b.textContent = t.backBtn;
    }
  });

  // Footer Home Buttons (navigational "Home" buttons with the house icon)
  document.querySelectorAll('.back-btn').forEach(function(b) {
    if (b.textContent.includes('Home') || b.textContent.includes('Ana Sayfa') || b.textContent.includes('الرئيسية')) {
      b.innerHTML = '&#8962; ' + t.btnHomeNav;
    }
  });
  applyScreenLanguage(screen);

  // Rebuild the currently visible data-driven screen after a language change.
  if (typeof visible === 'function') {
    if (visible('step-report') && state.report && typeof renderReport === 'function') renderReport(state.report);
    else if (visible('step-history') && typeof renderHistory === 'function') renderHistory(state._history || []);
    else if (visible('step-backups') && typeof renderBackupList === 'function') renderBackupList(state._backups || []);
    else if (visible('step-confirm') && typeof renderConfirm === 'function') renderConfirm();
    else if (visible('step-artwork') && typeof showArtwork === 'function') showArtwork();
    else if (visible('step-matches') && typeof showOtherMatches === 'function') showOtherMatches();
    else if (visible('step-noart') && typeof renderNoArt === 'function') renderNoArt();
  }
}

function applyScreenLanguage(screen) {
  var text = function(selector, value) {
    var node = document.querySelector(selector);
    if (node && typeof value === 'string') node.textContent = value;
  };
  var many = function(selector, values) {
    var nodes = document.querySelectorAll(selector);
    (values || []).forEach(function(value,index) {
      if (nodes[index] && typeof value === 'string') nodes[index].textContent = value;
    });
  };
  var placeholder = function(selector, value) {
    var node = document.querySelector(selector);
    if (node && typeof value === 'string') node.setAttribute('placeholder', value);
  };
  var titleAttr = function(selector, value) {
    var node = document.querySelector(selector);
    if (node && typeof value === 'string') node.setAttribute('title', value);
  };

  // Header controls
  text('#homeBtn', screen.homeHeader);
  text('#aboutBtn', screen.aboutHeader);
  text('#summaryBtn', screen.summaryHeader);
  text('#fsBtn', screen.fullScreen);
  text('header .ghost[onclick="quitApp()"]', screen.quit);

  // Setup / API key
  text('#step-key h2', screen.keyTitle);
  text('#step-key > p.sub', screen.keyIntro);
  many('#step-key .key-col-title', [screen.keyNew,screen.keyExisting]);
  many('#step-key .tut-step span:not(.tut-num)', screen.keySteps);
  many('#step-key .key-col .big-btn', [screen.keyCreate,screen.keyGet]);
  placeholder('#keyInput', screen.keyPlaceholder);
  text('#keyStorageNotice', screen.keyStorageNotice);
  many('#step-key .btn-row button', [screen.keyPaste,screen.keyContinue,screen.keyNoKey]);

  // No-art, History and About
  text('#step-noart h2', screen.noArtTitle);
  text('#step-noart p[style*="max-width"]', screen.noArtDescription);
  many('#noartBtns button', screen.noArtButtons);
  text('#step-history h2', screen.historyTitle);
  text('#step-history p.sub', screen.historySubtitle);
  placeholder('#historySearch', screen.historyPlaceholder);
  text('#step-history .btn-row button', screen.historyBack);
  text('#step-about h2', screen.aboutTitle);
  text('#step-about > p.sub', screen.aboutSubtitle);
  many('#step-about .about-h', screen.aboutHeadings);
  many('#step-about .about-card p', screen.aboutBodies);
  text('#step-about .btn-row button', screen.aboutHome);

  // Conversion, repair and health
  text('#step-convert-ok h2', screen.convertSuccessTitle);
  text('#step-convert-ok p[style*="max-width"]', screen.convertSuccessBody);
  text('#step-convert-ok .btn-row button', screen.convertContinue);
  text('#step-restore-ok h2', screen.doneTitle);
  text('#step-restore-ok .btn-row button', screen.doneHome);
  text('#step-health h2', screen.healthTitle);
  text('#step-health > p.sub', screen.healthSubtitle);
  many('#step-health .btn-row button', [screen.healthContinue,screen.cancel]);

  // New games and URL conversion
  text('#step-newgames h2', screen.newGamesTitle);
  text('#step-newgames > p.sub:not(#newGamesCount)', screen.newGamesPrompt);
  many('#step-newgames .btn-row button', [screen.newGamesOnly,screen.newGamesAll]);
  text('#step-convert h2', screen.convertTitle);
  many('#step-convert p.sub', [screen.convertBody1,screen.convertBody2]);
  many('#step-convert .btn-row button', [screen.convertProceed,screen.convertSkip]);

  // Folder picker screen and progress screen
  text('#step-folder > button.big-btn', screen.folderBrowse);
  placeholder('#folderInput', screen.folderPlaceholder);
  text('#loadingMsg', screen.loadingWorking);
  text('#loadCounter', screen.loadingWait);

  // Artwork and online image studio
  text('#vtGrid', screen.grid);
  text('#vtGallery', screen.gallery);
  text('#onlineSearchStatus', screen.onlineStatus);
  text('#customDropZone > div:nth-child(3)', screen.dropHelp);
  text('#customPreviewDropZone > div:first-child', screen.previewTitle);
  text('#fitCrop', screen.crop);
  text('#fitContain', screen.fit);
  text('#fitStretch', screen.stretch);
  titleAttr('#fitCrop', screen.crop);
  titleAttr('#fitContain', screen.fit);
  titleAttr('#fitStretch', screen.stretch);
  titleAttr('#customPreviewDropZone', screen.previewDropTitle);
  titleAttr('#customCanvas', screen.canvasDropTitle);
  text('#customUrlInput + button', screen.loadUrl);
  text('#customSkipBtn', '← ' + screen.cancelSkip.replace(/^←\s*/, ''));

  // Keep document controls and their accessible names in the selected language.
  var chooser = document.querySelector('#step-folder > button.big-btn');
  if (chooser) chooser.setAttribute('aria-label', screen.folderBrowse);
  var progress = document.getElementById('loadBar');
  if (progress) progress.setAttribute('aria-label', screen.loadingWorking);
  var languageSwitcher = document.getElementById('languageSwitcher');
  if (languageSwitcher) languageSwitcher.setAttribute('aria-label', screen.languageGroupLabel);
  var zoomButtons = document.querySelectorAll('header .zoombtn');
  if (zoomButtons.length >= 2) {
    zoomButtons[0].setAttribute('title', screen.zoomOutTitle);
    zoomButtons[1].setAttribute('title', screen.zoomInTitle);
  }
  var themeButton = document.getElementById('themeBtn');
  if (themeButton) themeButton.setAttribute('title', screen.cycleTheme || 'Change theme');
  var fullscreenButton = document.getElementById('fsBtn');
  if (fullscreenButton) fullscreenButton.setAttribute('title', screen.fullscreenTitle);
}

var state = {
  mode:'full', folder:'', items:[], pos:0, picks:{}, history:[],
  focusIdx:0, total:0, autoAll:false, zoom:1, homeFocus:0, report:null, editQueue:[], editReturnToReview:false, reviewSelected:{}, memoryAsked:false, useMemory:false, _applyConfirmed:false, onlyNew:false, gallery:false, _history:[], _autoApplyAfterScan:false, targetMode:'shortcuts', iconSearchOnly:false, scanIconSearchOnly:false, customGameReturnToMatches:false, _backups:[]
};
var coverCache = {};
var currentPollId = 0;

// Cover previews use a small, prioritized queue instead of eager-loading every
// candidate at once. This keeps the visible picker responsive on slow CDNs.
var coverLoadQueue = [];
var coverActiveTasks = [];
var coverActiveLoads = 0;
var coverLoadSequence = 0;
var coverGridObserver = null;
var MAX_CONCURRENT_COVER_LOADS = 4;

function stopCoverImageLoading(){
  if (coverGridObserver){ coverGridObserver.disconnect(); coverGridObserver = null; }
  coverLoadQueue = [];
  coverActiveTasks.slice().forEach(function(job){
    if (!job || job.done) return;
    job.done = true;
    coverActiveLoads = Math.max(0, coverActiveLoads - 1);
    if (job.img){
      job.img.onload = null;
      job.img.onerror = null;
      try { job.img.removeAttribute('src'); } catch(e){}
      job.img.dataset.coverState = 'cancelled';
    }
  });
  coverActiveTasks = [];
}

function pumpCoverImageQueue(){
  coverLoadQueue.sort(function(a,b){
    return (b.priority - a.priority) || (a.sequence - b.sequence);
  });
  while (coverActiveLoads < MAX_CONCURRENT_COVER_LOADS && coverLoadQueue.length){
    var job = coverLoadQueue.shift();
    if (!job || !job.img || !job.img.isConnected || job.img.dataset.coverState !== 'queued') continue;
    job.done = false;
    job.img.dataset.coverState = 'loading';
    coverActiveLoads++;
    coverActiveTasks.push(job);
    (function(task){
      function complete(ok){
        if (task.done) return;
        task.done = true;
        coverActiveLoads = Math.max(0, coverActiveLoads - 1);
        coverActiveTasks = coverActiveTasks.filter(function(active){ return active !== task; });
        if (task.img && task.img.isConnected){
          task.img.dataset.coverState = ok ? 'loaded' : 'error';
          task.img.classList.remove('cover-loading');
          task.img.classList.add(ok ? 'cover-ready' : 'cover-error');
          if (!ok) task.img.alt = 'Preview unavailable';
        }
        pumpCoverImageQueue();
      }
      task.img.onload = function(){ complete(true); };
      task.img.onerror = function(){ complete(false); };
      task.img.src = task.url;
    })(job);
  }
}

function queueCoverImage(img, url, priority){
  if (!img || !url || img.dataset.coverState) return;
  img.dataset.coverState = 'queued';
  coverLoadQueue.push({
    img: img, url: url, priority: Number(priority) || 0,
    sequence: coverLoadSequence++, done: false
  });
}

function observeCoverImages(grid){
  var imgs = grid.querySelectorAll('img[data-cover-src]');
  if (typeof window.IntersectionObserver === 'function'){
    var observer = new IntersectionObserver(function(entries){
      entries.forEach(function(entry){
        if (!entry.isIntersecting) return;
        observer.unobserve(entry.target);
        queueCoverImage(entry.target, entry.target.dataset.coverSrc, entry.target.dataset.coverPriority);
      });
      pumpCoverImageQueue();
    }, { root: grid, rootMargin: '120px 0px', threshold: 0.01 });
    coverGridObserver = observer;
    imgs.forEach(function(img){ observer.observe(img); });
  } else {
    imgs.forEach(function(img){
      queueCoverImage(img, img.dataset.coverSrc, img.dataset.coverPriority);
    });
    pumpCoverImageQueue();
  }
}

function $(id){ return document.getElementById(id); }
var SCREENS = ['step-custom','step-convert','step-convert-ok','step-memory','step-newgames','step-restore-ok','step-backups','step-history','step-about','step-health','step-confirm-apply','step-key','step-noart','step-home','step-folder','step-loading','step-confirm','step-artwork','step-matches','step-review','step-report'];
function show(id){
  if (id !== 'step-artwork') stopCoverImageLoading();
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
  var value = pct == null ? 0 : Math.max(0,Math.min(100,Math.round(Number(pct)||0)));
  $('loadingMsg').textContent = msg || 'Working...';
  $('loadingMsg').classList.remove('typed-caret');
  $('loadDetail').textContent = detail || '';
  $('loadFill').style.width = value + '%';
  $('loadPercent').textContent = value + '%';
  $('loadBar').setAttribute('aria-valuenow', String(value));
  $('loadCounter').textContent = '';
  $('autoFeed').innerHTML = '';
  show('step-loading');
}
function setLoadProgress(detail, pct, current, total){
  $('loadDetail').textContent = detail || '';
  if (pct != null){
    var value = Math.max(0,Math.min(100,Math.round(Number(pct)||0)));
    $('loadFill').style.width = value + '%';
    $('loadPercent').textContent = value + '%';
    $('loadBar').setAttribute('aria-valuenow', String(value));
  }
  if (Number.isFinite(Number(current)) && Number.isFinite(Number(total))) {
    $('loadCounter').textContent = formatStr(statusText('scannedCounter'), [Number(current),Number(total)]);
  } else {
    var match = String(detail||'').match(/Found\s+(\d+)\s+of\s+(\d+)/i);
    if (match) $('loadCounter').textContent = formatStr(statusText('scannedCounter'), [match[1],match[2]]);
  }
}

// ---- theme / zoom / fullscreen ----
var THEMES = [
  { id:'glass',         name:'Aurora Glass', icon:'\u25C8' },
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
  var screen = screenI18n[currentLang] || screenI18n.en;
  document.documentElement.setAttribute('data-theme', t.id);
  $('themeIcon').innerHTML = t.icon;
  $('themeTxt').textContent = (screen.themeNames && screen.themeNames[themeIdx]) || t.name;
  $('themeBtn').setAttribute('aria-label', (screen.cycleTheme || 'Change theme') + ': ' + $('themeTxt').textContent);
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
  var screen = screenI18n[currentLang] || screenI18n.en;
  $('fsBtn').textContent = document.fullscreenElement ? screen.exitFullscreen : screen.fullScreen;
});

function api(path, body){
  var headers = {'Content-Type':'application/json'};
  // Each browser profile supplies its own SteamGridDB key to the local server.
  // The key is never embedded in the application or written to settings.json.
  try {
    var localApiKey = localStorage.getItem('gis-sgdb-api-key') || '';
    if (localApiKey) headers['X-GIS-API-Key'] = localApiKey;
  } catch(e) {}
  return fetch(path, { method:'POST', headers:headers, body: JSON.stringify(body||{}) })
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
  api('/api/finish', {}).finally(function(){ location.reload(); });
}


// ---- image preloading ----
function preloadItem(it){
  if (!it || !it.sections) return;
  // Warm only the first candidate for the current item; the cover picker
  // schedules the other previews as they become visible.
  var sec = it.sections[0];
  var c = sec && sec.covers && sec.covers[0];
  if (c && c.thumb && !coverCache[c.thumb]){
    var img = new Image();
    img.decoding = 'async';
    img.src = c.thumb;
    coverCache[c.thumb] = img;
  }
}
function preloadAround(pos){
  if (state.items[pos]) preloadItem(state.items[pos]);
}

// ---- API KEY ----
function showKeySetup(message){
  show('step-key');
  if (message) $('keyMsg').textContent = message;
  setTimeout(function(){ $('keyInput').focus(); }, 100);
}
function getLocalApiKey(){
  try { return (localStorage.getItem('gis-sgdb-api-key') || '').trim(); }
  catch(e){ return ''; }
}
function requireApiKeyForGameArtwork(){
  if (getLocalApiKey()) return true;
  showKeySetup((screenI18n[currentLang] || screenI18n.en).keyRequiredMessage);
  return false;
}
function checkKey(){
  var savedKey = getLocalApiKey();
  if (!savedKey){ showKeySetup(); return; }
  $('keyMsg').textContent = statusText('checkingKey');
  api('/api/save-key', { key: savedKey }).then(function(res){
    if (res && res.ok){
      $('keyMsg').textContent = '';
      showHome();
    } else {
      try { localStorage.removeItem('gis-sgdb-api-key'); } catch(e){}
      $('keyInput').value = '';
      showKeySetup((res && res.error) || statusText('invalidKey'));
    }
  }).catch(function(){
    showKeySetup(statusText('localServerError'));
  });
}
function openUrl(u){ try { window.open(u, '_blank'); } catch(e){} }
function pasteKey(){
  if (navigator.clipboard && navigator.clipboard.readText){
    navigator.clipboard.readText().then(function(t){
      $('keyInput').value = (t||'').trim();
      saveKey();
    }).catch(function(){ $('keyMsg').textContent = statusText('clipboardError'); });
  } else {
    $('keyMsg').textContent = statusText('pasteKeyHint');
  }
}
function continueWithoutKey(){
  // Keyless access is limited to the dedicated Google/Yandex app-icon workflows.
  showHome();
}
function saveKey(){
  var key = $('keyInput').value.trim();
  if (!key){ $('keyMsg').textContent = statusText('needKey'); return; }
  $('keyMsg').textContent = statusText('checkingKey');
  api('/api/save-key', { key: key }).then(function(res){
    if (res && res.ok){
      try {
        localStorage.setItem('gis-sgdb-api-key', key);
        $('keyInput').value = '';
        $('keyMsg').textContent = '';
        goHome();
      } catch(e){
        $('keyMsg').textContent = 'Browser storage is unavailable. Enable site storage for localhost and try again.';
      }
    } else {
      $('keyMsg').textContent = (res && res.error) || statusText('invalidKey');
    }
  }).catch(function(){
    $('keyMsg').textContent = statusText('localServerError');
  });
}

// ---- HOME ----
// Hard refresh: fully clears frontend state (and the backend session
// via the '/' route) so a half-open dialog can never lock the UI.
function goHome(){
  location.reload();
}
// In-page home used by the startup path (checkKey) to avoid a reload loop.
function showHome(){
  currentPollId++; // Cancel any active dialog polling
  state.autoAll = false;
  state.iconSearchOnly = false;
  setProgress(0);
  // Reset folder screen text to default
  state.targetMode = 'shortcuts';
  updateFolderScreenLabels();
  // If there is still no key, stay on the key screen.
  show('step-home');
  state.homeFocus = 0; focusHome();
}
function focusHome(){
  document.querySelectorAll('.home-btn').forEach(function(b,i){ b.classList.toggle('focus', i===state.homeFocus); });
}


// ---- Quick re-apply (#10) ----
function quickReapply(){
  setLoading(statusText('gettingReady'), statusText('loadingSavedChoices'), 0);
  api('/api/last-folder', {}).then(function(res){
    if (!(res.ok && res.folder)){
      $('restoreResultMsg').textContent = statusText('noPreviousFolder');
      show('step-restore-ok');
      return;
    }
    api('/api/saved-status', {}).then(function(st){
      if (!st || !st.ok || st.count === 0){
        $('restoreResultMsg').textContent = statusText('noSavedChoices');
        show('step-restore-ok');
        return;
      }
      // Reuse the full pipeline with memory on, applying everything
      // automatically end to end.
      state.folder = res.folder;
      state.mode = 'full';
      state.iconSearchOnly = false;
      state.targetMode = 'shortcuts';
      state.onlyNew = false;
      state.memoryAsked = true;
      state.useMemory = true;
      state.autoAll = true;          // auto-accept remembered/best picks
      state._applyConfirmed = true;  // skip the confirm gate for a one-click redo
      doScan();
    });
  });
}

function undoLastIconChange(){
  setLoading(statusText('checkingSavedBackups'), statusText('readingBackups'), 10);
  api('/api/backup-list', {}).then(function(result){
    var backups = Array.isArray(result && result.backups) ? result.backups : [];
    backups = backups.filter(function(item){ return !item.RestoredAt; });
    backups.sort(function(a,b){ return new Date(b.CreatedAt||0).getTime() - new Date(a.CreatedAt||0).getTime(); });
    if (!backups.length){
      $('restoreResultMsg').textContent = statusText('noUnusedRestore');
      show('step-restore-ok');
      return;
    }
    var latest = backups[0];
    var message = formatStr(statusText('undoConfirm'), [latest.CreatedAt||latest.Id, latest.ItemCount||0]);
    if (!window.confirm(message)){ goHome(); return; }
    setLoading(statusText('restoringPreviousState'), statusText('reversingLatest'), 35);
    api('/api/backup-restore-latest', {}).then(function(res){
      var failures = (res && res.failures && res.failures.length) ? '\\n\\n' + res.failures.slice(0,8).join('\\n') : '';
      $('restoreResultMsg').textContent = (res && res.message) ? res.message + failures : (res && res.error) || 'The latest restore point could not be restored.';
      show('step-restore-ok');
    }).catch(function(error){
      $('restoreResultMsg').textContent = (error && error.message) || 'The latest restore point could not be restored.';
      show('step-restore-ok');
    });
  }).catch(function(error){
    $('restoreResultMsg').textContent = (error && error.message) || 'Could not read the backup list.';
    show('step-restore-ok');
  });
}

function showAbout(){ show('step-about'); setNavFocus(null); window.scrollTo(0,0); var c=$('step-about'); if(c) c.scrollTop=0; }
function aboutDone(){
  // If the user has not set an API key yet, send them back to setup;
  // otherwise go to the home screen.
  api('/api/key-status', {}).then(function(res){
    if (res && res.hasKey){ showHome(); } else { show('step-key'); }
  }).catch(function(){ showHome(); });
}

// ---- History (#15) ----
function openHistory(){
  setLoading(statusText('loadingHistory'), '', 0);
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
    wrap.textContent = statusText('historyEmpty');
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


function openBackups(){
  $('backupList').innerHTML = '';
  $('backupSettingStatus').textContent = '';
  setLoading(statusText('loadingBackups'), statusText('readingBackups'), 15);
  Promise.all([
    api('/api/backup-list', {}),
    api('/api/backup-settings', {})
  ]).then(function(results){
    var listRes = results[0] || {};
    var settingRes = results[1] || {};
    state._backups = Array.isArray(listRes.backups) ? listRes.backups : [];
    if (settingRes.ok && $('backupRetention')) $('backupRetention').value = String(settingRes.retention);
    renderBackupList(state._backups);
    show('step-backups');
  }).catch(function(){
    $('backupList').textContent = statusText('backupListError');
    show('step-backups');
  });
}
function renderBackupList(list){
  var wrap = $('backupList');
  wrap.innerHTML = '';
  var t = i18n[currentLang] || i18n.en;
  if (!list.length){
    var empty = document.createElement('div');
    empty.className = 'sub';
    empty.style.cssText = 'text-align:center;padding:24px;';
    empty.textContent = t.backupEmpty;
    wrap.appendChild(empty);
    return;
  }
  list.forEach(function(item){
    var row = document.createElement('div');
    row.className = 'history-row';
    row.style.cssText = 'gap:16px;padding:16px;align-items:center;';
    var info = document.createElement('div');
    info.className = 'hist-info';
    var name = document.createElement('div');
    name.className = 'hist-name';
    name.textContent = formatStr(statusText('backupItemCount'), [item.itemCount || 0, item.createdAt || item.id || 'Unknown date']);
    var sub = document.createElement('div');
    sub.className = 'hist-sub';
    sub.textContent = item.restoredAt ? formatStr(statusText('backupPreviouslyRestored'), [item.restoredAt]) : statusText('backupOriginalSaved');
    info.appendChild(name); info.appendChild(sub);
    var btn = document.createElement('button');
    btn.className = 'ghost g-good';
    btn.textContent = t.backupRestore;
    btn.addEventListener('click', function(){ restoreBackup(item.id, item.itemCount || 0); });
    row.appendChild(info); row.appendChild(btn); wrap.appendChild(row);
  });
}
function saveBackupRetention(){
  var value = parseInt($('backupRetention').value, 10);
  if (!Number.isFinite(value) || value < 0) value = 50;
  api('/api/backup-settings', { retention: value }).then(function(res){
    $('backupSettingStatus').textContent = (res && res.ok) ? i18n[currentLang].backupSaved : ((res && res.error) || statusText('backupSaveError'));
  }).catch(function(){ $('backupSettingStatus').textContent = statusText('backupSaveError'); });
}
function restoreBackup(id, count){
  var t = i18n[currentLang] || i18n.en;
  if (!window.confirm(formatStr(t.backupRestoreConfirm, [count, id]))) return;
  setLoading(statusText('restoringIcons'), statusText('restoringDetail'), 55);
  api('/api/backup-restore', { id: id }).then(function(res){
    var failures = (res && res.failures && res.failures.length) ? '\n\n' + res.failures.slice(0,8).join('\n') : '';
    $('restoreResultMsg').textContent = (res && res.message) ? res.message + failures : (res && res.error) || t.backupRestoreError;
    show('step-restore-ok');
  }).catch(function(){
    $('restoreResultMsg').textContent = t.backupRestoreError;
    show('step-restore-ok');
  });
}

function repairIconCache(){
  setLoading(statusText('chooseRepairFolder'), statusText('repairFolderDetail'), null);
  api('/api/browse-folder', { lang: currentLang }).then(function(){
    pollDialog(function(dialogResult){
      if (!dialogResult.ok || !dialogResult.folder){ goHome(); return; }
      state.folder = dialogResult.folder;
      setLoading(statusText('repairingIcons'), statusText('repairingDetail'), 0);
      api('/api/repair-shortcut-icons', { folder: dialogResult.folder }).then(function(res){
        if (!res || (!res.ok && !res.cacheRefreshed)) {
          $('restoreResultMsg').textContent = (res && res.error) || statusText('repairError');
        } else {
          var parts = [
            formatStr(statusText('repairScanned'), [res.scanned||0]),
            formatStr(statusText('repairRepaired'), [res.repaired||0]),
            formatStr(statusText('repairRebuilt'), [res.rebuilt||0]),
            formatStr(statusText('repairAlreadyValid'), [res.alreadyValid||0]),
            formatStr(statusText('repairUnresolved'), [res.unresolved||0]),
            formatStr(statusText('repairFailed'), [res.failed||0])
          ];
          if (res.cacheRefreshed) parts.push(statusText('repairCacheRefreshed'));
          if ((res.unresolved||0)>0) parts.push(statusText('repairMissingArtwork'));
          $('restoreResultMsg').textContent = parts.join('\n');
        }
        show('step-restore-ok');
      }).catch(function(error){
        $('restoreResultMsg').textContent = (error && error.message) || statusText('repairRequestError');
        show('step-restore-ok');
      });
    });
  }).catch(function(error){
    $('restoreResultMsg').textContent = (error && error.message) || statusText('pickerError');
    show('step-restore-ok');
  });
}

// ---- FULL SCAN flow ----
function startFullScan(iconSearchOnly){
  if (!iconSearchOnly && !requireApiKeyForGameArtwork()) return;
  state.gameFilesSummary = '';
  state.mode = 'full';
  state.targetMode = 'shortcuts';
  state.iconSearchOnly = !!iconSearchOnly;
  // Program/App mode is batch-first: auto-match every available icon and
  // reveal the complete preview grid instead of asking for each item in turn.
  state.autoAll = !!iconSearchOnly;
  state.useMemory = false;
  state.onlyNew = false; state.memoryAsked = false;
  updateFolderScreenLabels();
  setProgress(0);
  show('step-folder');
  $('folderPath').textContent = '';
  $('scanBtn').classList.add('hidden');
  $('folderInput').value = '';
  api('/api/last-folder', {}).then(function(res){
    if (res.ok && res.folder){
      state.folder = res.folder;
      $('folderInput').value = res.folder;
      $('folderPath').textContent = statusText('lastFolderReady');
      $('scanBtn').classList.remove('hidden');
      if (!state.iconSearchOnly) maybeOfferNewGames();
    }
  });
}
function updateFolderScreenLabels(){
  var ft = document.getElementById('folderTitle'), fs = document.getElementById('folderSubtitle'), sb = document.getElementById('scanBtn');
  if (!ft || !fs) return;
  var t = i18n[currentLang];
  if (state.iconSearchOnly) {
    ft.textContent = t.programFolderTitle;
    fs.textContent = t.programFolderSub;
    if (sb) sb.textContent = t.programScanBtn;
  } else if (state.targetMode === 'folders_all'){
    ft.textContent = t.ftMainAll;
    fs.textContent = t.fsMainAll;
    if (sb) sb.textContent = t.btnScanAll;
  } else if (state.targetMode === 'folders_single'){
    ft.textContent = t.ftSingle;
    fs.textContent = t.fsSingle;
    if (sb) sb.textContent = t.btnScanSingle;
  } else if (state.targetMode === 'game_files'){
    var screen = screenI18n[currentLang] || screenI18n.en;
    ft.textContent = screen.gameFilesTitle;
    fs.textContent = screen.gameFilesDesc;
    if (sb) sb.textContent = screen.gameFilesButton;
  } else {
    ft.textContent = t.folderTitle;
    fs.textContent = t.folderSub;
    if (sb) sb.textContent = t.scanBtn;
  }
}
function startGameFilesFolder(){
  if (!requireApiKeyForGameArtwork()) return;
  state.mode = 'change';
  state.iconSearchOnly = false;
  state.targetMode = 'game_files';
  state.autoAll = true;
  state.useMemory = false;
  state.onlyNew = false;
  state.memoryAsked = true;
  state.gameFilesSummary = '';
  updateFolderScreenLabels();
  setProgress(0);
  browseFolder();
}

function startFolderMode(type){
  if (!requireApiKeyForGameArtwork()) return;
  state.gameFilesSummary = '';
  state.mode = 'full';
  state.iconSearchOnly = false;
  state.targetMode = (type === 'all') ? 'folders_all' : 'folders_single';
  state.onlyNew = false; state.memoryAsked = false;
  setProgress(0);
  // Update folder screen text based on mode
  updateFolderScreenLabels();
  browseFolder();
}
function isFolderMode(){
  return (state.targetMode === 'folders_all' || state.targetMode === 'folders_single');
}
function browseFolder(){
  var screen = screenI18n[currentLang] || screenI18n.en;
  var detail = screen.browseFolderGeneric;
  if (state.targetMode === 'folders_all'){ detail = screen.browseFolderAll || screen.browseFolderGeneric; }
  if (state.targetMode === 'folders_single'){ detail = screen.browseFolderSingle || screen.browseFolderGeneric; }
  if (state.targetMode === 'game_files'){ detail = screen.browseFolderDetail; }
  setLoading(statusText('openingFolder'), detail, null);
  api('/api/browse-folder', { lang: currentLang }).then(function(){
    pollDialog(function(res){
      if (res.ok && res.folder){
        state.folder = res.folder;
        folderReady(res.folder);
      } else {
        show('step-folder');
        $('folderPath').textContent = statusText('noFolderChosen');
      }
    });
  });
}
// Land on the folder screen with everything available, then start the
// scan automatically (no extra Scan click needed).
function folderReady(folder){
  show('step-folder');
  $('folderInput').value = folder;
  $('folderPath').textContent = statusText('folderReady');
  $('scanBtn').classList.remove('hidden');
  if (isFolderMode() || state.iconSearchOnly){ startScan(); return; }
  // Both Shortcuts Only and Game Library mode compare full file paths.
  api('/api/new-games-count', { folder: folder, targetMode: state.targetMode }).then(function(res){
    if (res && res.ok && res.knownFolder && Number(res.newCount) > 0){
      $('newGamesCount').textContent = formatStr(statusText('newGamesCount'), [res.newCount]);
      show('step-newgames');
    } else if (state.targetMode === 'game_files') {
      scanGameFilesFolder(folder, false);
    } else {
      startScan();
    }
  }).catch(function(){
    if (state.targetMode === 'game_files') scanGameFilesFolder(folder, false);
    else startScan();
  });
}

// Polls the async native dialog without blocking. Keeps the browser
// responsive while the Windows window is open, and refocuses the
// browser when it closes.
function pollDialog(done){
  currentPollId++;
  var myId = currentPollId;
  var tick = function(){
    if (myId !== currentPollId) return; // Abort if a new poll or navigation occurred
    api('/api/dialog-status', {}).then(function(res){
      if (myId !== currentPollId) return;
      if (res.status === 'done'){
        try { window.focus(); } catch(e){}
        done(res);
      } else {
        setTimeout(tick, 350);
      }
    }).catch(function(){
      if (myId === currentPollId) setTimeout(tick, 500);
    });
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
      $('folderPath').textContent = statusText('invalidFolderPath');
    }
  });
}

function scanGameFilesFolder(folder, onlyNew){
  state.mode = 'change';
  state.iconSearchOnly = false;
  state.autoAll = true;
  state.useMemory = true;
  state.onlyNew = !!onlyNew;
  state.memoryAsked = true;
  state.gameFilesSummary = '';
  setLoading(statusText('findingGames'), statusText('scanningFolder'), 0);
  api('/api/scan-game-folder-begin', { folder: folder, onlyNew: state.onlyNew }).then(function(res){
    if (!res || !res.ok){
      show('step-folder');
      $('folderPath').textContent = (res && res.error) ? res.error : statusText('gameFolderScanError');
      return;
    }
    var details = [];
    details.push(formatStr(statusText('launchableEntries'), [res.sourceFiles||0]));
    details.push(formatStr(statusText('exeCount'), [res.includedExecutables||0]));
    if (res.includedScripts) details.push(formatStr(statusText('scriptCount'), [res.includedScripts]));
    if (res.includedShortcuts) details.push(formatStr(statusText('existingShortcutCount'), [res.includedShortcuts]));
    if (res.convertedUrls) details.push(formatStr(statusText('preparedLauncherCount'), [res.convertedUrls]));
    if (res.includedRoms) details.push(formatStr(statusText('romCount'), [res.includedRoms]));
    if (res.alreadyLinked) details.push(formatStr(statusText('linkedCount'), [res.alreadyLinked]));
    if (res.excludedLauncherApps) details.push(formatStr(statusText('launcherUtilityCount'), [res.excludedLauncherApps]));
    if (res.excludedHelpers) details.push(formatStr(statusText('helperSkippedCount'), [res.excludedHelpers]));
    if (res.failedUrls) details.push(formatStr(statusText('failedUrlCount'), [res.failedUrls]));
    if (res.truncated) details.push(formatStr(statusText('safetyLimitCount'), [res.truncated]));
    state.gameFilesSummary = details.join(' · ') + '. ' + statusText('originalsUntouched');
    beginScanLoop(res.total);
  }).catch(function(error){
    show('step-folder');
    $('folderPath').textContent = (error && error.message) ? error.message : statusText('gameFolderScanFailed');
  });
}

function startScan(){
  setProgress(0);
  // Folder modes have no .lnk health check or .url conversion step.
  if (isFolderMode()){ runScan(); return; }
  setLoading(statusText('checkingFolder'), statusText('checkingShortcuts'), 0);
  api('/api/folder-health', { folder: state.folder }).then(function(h){
    var row = $('healthRow'); row.innerHTML = '';
    var cards = [
      [statusText('standardShortcuts'), h.lnk||0, 'var(--good)'],
      [statusText('launcherShortcuts'), h.url||0, 'var(--warn)'],
      [statusText('brokenTargetLabel'), h.broken||0, (h.broken>0?'var(--bad)':'var(--muted)')]
    ];
    cards.forEach(function(c){
      var d=document.createElement('div'); d.className='health-card';
      d.innerHTML='<div class="health-n" style="color:'+c[2]+'">'+c[1]+'</div><div class="health-l">'+c[0]+'</div>';
      row.appendChild(d);
    });
    var notes=[];
    if ((h.url||0)>0){ notes.push(statusText('healthLauncherNote')); }
    if ((h.broken||0)>0){ notes.push(statusText('healthBrokenNote')); }
    if (!notes.length){ notes.push(statusText('everythingGood')); }
    $('healthNote').textContent = notes.join(' ');
    show('step-health');
  }).catch(function(){ afterHealth(); });
}
function healthContinue(){ afterHealth(); }
function afterHealth(){
  setLoading(statusText('checkingFolder'), statusText('checkingShortcuts'), 0);
  api('/api/check-url-shortcuts', { folder: state.folder }).then(function(chk){
    if (chk && chk.ok && chk.urlCount > 0){
      $('convertCount').textContent = formatStr(statusText('launcherCount'), [chk.urlCount, chk.lnkCount>0 ? formatStr(statusText('andShortcutCount'), [chk.lnkCount]) : '']);
      show('step-convert');
    } else {
      runScan();
    }
  }).catch(function(){ runScan(); });
}
function doConvert(){
  setLoading(statusText('convertingShortcuts'), statusText('convertingDetail'), 30);
  api('/api/convert-shortcuts', { folder: state.folder }).then(function(res){
    var n = (res && res.converted) ? res.converted : 0;
    showConvertSuccess(n);
  }).catch(function(){ runScan(); });
}
function showConvertSuccess(n){
  $('convertOkCount').textContent = n
    ? formatStr(statusText('convertedCount'), [n])
    : statusText('shortcutsReady');
  show('step-convert-ok');
}
function skipConvert(){ runScan(); }
function runScan(){
  // Previously selected artwork is the default on every scan.
  state.useMemory = true;
  state.memoryAsked = true;
  doScan();
}
function memoryLoad(){ state.useMemory = true; doScan(); }
function memoryReset(){
  // Ignore saved choices for this scan only. Do not erase choices.json.
  state.useMemory = false;
  doScan();
}
function doScan(){
  setProgress(0);
  var folderMode = isFolderMode();
  var msg = state.iconSearchOnly ? statusText('scanPreparingPrograms') : (folderMode ? statusText('scanSteamFolders') : statusText('scanSteamGames'));
  var detail = state.iconSearchOnly ? statusText('readingAppShortcuts') : (folderMode ? statusText('readingFolders') : statusText('readingFolder'));
  setLoading(msg, detail, 0);
  var payload = { folder: state.folder };
  if (state.iconSearchOnly) payload.iconSearchOnly = true;
  if (state.onlyNew){ payload.onlyNew = true; }
  if (state.targetMode){ payload.targetMode = state.targetMode; }
  api('/api/scan-begin', payload).then(function(res){
    if (!res.ok){ show('step-folder'); $('folderPath').textContent = res.error || statusText('scanFailed'); return; }
    beginScanLoop(res.total);
  });
}

// ---- New-game detection (#13) ----
function maybeOfferNewGames(){
  if (!state.folder) return;
  api('/api/new-games-count', { folder: state.folder }).then(function(res){
    if (res && res.ok && res.knownFolder && res.newCount > 0){
      $('newGamesCount').textContent = formatStr(statusText('newGamesCount'), [res.newCount]);
      show('step-newgames');
    }
  }).catch(function(){});
}
function scanNewOnly(){
  state.onlyNew = true;
  state.memoryAsked = true;
  state.useMemory = true;
  if (state.targetMode === 'game_files') {
    scanGameFilesFolder(state.folder, true);
    return;
  }
  state.mode = 'full';
  doScan();
}
function scanAllInstead(){
  state.onlyNew = false;
  if (state.targetMode === 'game_files') {
    scanGameFilesFolder(state.folder, false);
    return;
  }
  startScan();
}

// ---- CHANGE ICONS flow ----
function startChangeIcons(anyFiles){
  if (!anyFiles && !requireApiKeyForGameArtwork()) return;
  state.gameFilesSummary = '';
  state.mode = 'change';
  state.iconSearchOnly = !!anyFiles;
  state.targetMode = 'shortcuts';
  state.autoAll = false;
  state.useMemory = false;
  state.onlyNew = false;
  state.editQueue = [];
  state.editReturnToReview = false;
  setProgress(0);
  setLoading(statusText('openingFolder'), statusText('selectFilesDetail'), null);
  api('/api/change-files', { lang: currentLang }).then(function(){
    pollDialog(function(res){
      if (!res.ok || !res.files || !res.files.length){ goHome(); return; }
      setLoading(state.iconSearchOnly ? statusText('programFilesScanning') : statusText('scanningGames'), statusText('readingFiles'), 0);
      api('/api/scan-files-begin', { files: res.files, iconSearchOnly: state.iconSearchOnly }).then(function(r2){
        if (!r2.ok){ alert(r2.error || 'Could not read those files.'); goHome(); return; }
        beginScanLoop(r2.total);
      });
    });
  });
}

// ---- shared scan loop ----
function beginScanLoop(total){
  state.scanIconSearchOnly = !!state.iconSearchOnly;
  state.items = []; state.pos = 0; state.picks = {}; state.history = []; state.reviewSelected = {};
  state.editQueue = []; state.editReturnToReview = false;
  state.total = total || 0;
  if (state.total === 0){ alert(state.iconSearchOnly ? statusText('noSupportedFiles') : statusText('noGamesMatched')); goHome(); return; }
  // Program mode queries external image engines per item, so show a realistic estimate.
  var seconds = estimateSeconds(state.total, state.iconSearchOnly ? 13 : 0.6);
  var duration = seconds < 60
    ? formatStr(statusText('aboutSeconds'), [seconds])
    : formatStr(statusText('aboutMinutes'), [Math.round(seconds/60)]);
  var noun = state.iconSearchOnly ? statusText('programFileIconNoun') : (state.total === 1 ? statusText('gameSingular') : statusText('gamesPlural'));
  var detail = formatStr(statusText('scanEstimate'), [duration,state.total,noun]);
  if (state.iconSearchOnly) detail += ' ' + statusText('programSearchDetail');
  if (state.gameFilesSummary) detail = state.gameFilesSummary + ' ' + detail;
  setLoading(state.iconSearchOnly ? statusText('findingProgramIcons') : statusText('scanningGames'), detail, 0);
  scanStep(0);
}
function estimateSeconds(count, perItem){
  return Math.max(1, Math.round(count * perItem));
}
function rasterizeImageDataUrlToPng(dataUrl, size){
  size = size || 256;
  return new Promise(function(resolve){
    var img = new Image();
    img.onload = function(){
      try {
        var canvas = document.createElement('canvas'); canvas.width = size; canvas.height = size;
        var ctx = canvas.getContext('2d'); ctx.clearRect(0,0,size,size);
        var iw = img.naturalWidth || img.width, ih = img.naturalHeight || img.height;
        if (!iw || !ih) { resolve(''); return; }
        var scale = Math.min(size/iw, size/ih), dw = Math.round(iw*scale), dh = Math.round(ih*scale);
        ctx.drawImage(img, Math.round((size-dw)/2), Math.round((size-dh)/2), dw, dh);
        resolve(canvas.toDataURL('image/png'));
      } catch(e) { resolve(''); }
    };
    img.onerror = function(){ resolve(''); };
    img.src = dataUrl;
  });
}
function prepareIconifyCandidatesInBrowser(it){
  if (!(state.iconSearchOnly || (it && it.iconSearchOnly)) || !it || !it.sections || !it.sections.length) return Promise.resolve();
  var covers = it.sections[0].covers || [];
  var vectors = covers.filter(function(c){ return c && /^Iconify\s*\//i.test(String(c.source||'')) && /\.svg(?:[?#]|$)/i.test(String(c.url||'')); }).slice(0,8);
  if (!vectors.length) return Promise.resolve();
  var tasks = vectors.map(function(candidate,index){
    return api('/api/fetch-remote-image',{url:candidate.url}).then(function(res){
      if (!res || !res.ok || !/^data:image\/svg\+xml/i.test(String(res.dataUrl||''))) return null;
      return rasterizeImageDataUrlToPng(res.dataUrl,256).then(function(png){
        if (!png) return null;
        var cacheName = String(it.name||'app') + '-iconify-' + String(index+1);
        return api('/api/custom-cover',{name:it.name,cacheName:cacheName,dataUrl:png}).then(function(saved){
          if (saved && saved.ok && saved.url){
            candidate.url = saved.url; candidate.thumb = saved.url;
            candidate.source = String(candidate.source||'Iconify') + ' (PNG preview)';
            candidate.width = 256; candidate.height = 256;
            return candidate;
          }
          return null;
        });
      });
    }).catch(function(){ return null; });
  });
  return Promise.all(tasks).then(function(){
    // The normal ICO pipeline cannot consume an un-rasterized SVG URL. Keep only
    // converted Iconify items in the batch review grid; manual search still lists all sources.
    it.sections.forEach(function(section){
      if (section && section.covers) section.covers = section.covers.filter(function(c){
        return !(/^Iconify\s*\//i.test(String(c.source||'')) && /\.svg(?:[?#]|$)/i.test(String(c.url||'')));
      });
    });
    preloadItem(it);
  });
}

function rankProgramCandidatesInBrowser(it){
  return new Promise(function(resolve){
    if (!(state.iconSearchOnly || (it && it.iconSearchOnly)) || !it || !it.sections || !it.sections.length || !it.sections[0].covers || it.sections[0].covers.length < 2) { resolve(); return; }
    var section = it.sections[0], covers = section.covers;
    var sample = covers.slice(0, Math.min(5, covers.length));
    var remaining = sample.length, finished = false;
    var timer = setTimeout(finish, 1800);
    function finish(){
      if (finished) return; finished = true; clearTimeout(timer);
      covers.sort(function(a,b){ return (+b.clientScore || +b.score || 0) - (+a.clientScore || +a.score || 0); });
      state.picks[it.index] = { game:1, cover:1 };
      resolve();
    }
    function completeOne(){ remaining--; if (remaining <= 0) finish(); }
    sample.forEach(function(candidate){
      if (!candidate || !candidate.url || /^\/cache\//i.test(candidate.url)) { completeOne(); return; }
      var probe = new Image();
      probe.referrerPolicy = 'no-referrer';
      probe.onload = function(){
        var w = probe.naturalWidth || 0, h = probe.naturalHeight || 0;
        if (w > 0 && h > 0){
          candidate.actualWidth = w; candidate.actualHeight = h;
          var ratio = Math.min(w,h) / Math.max(w,h), minSide = Math.min(w,h);
          var score = (+candidate.score || 45);
          score += ratio >= .94 ? 5 : (ratio >= .82 ? 2 : (ratio >= .65 ? 0 : -10));
          score += minSide >= 1024 ? 5 : (minSide >= 512 ? 4 : (minSide >= 256 ? 2 : -12));
          candidate.clientScore = Math.max(1,Math.min(100,Math.round(score)));
        }
        completeOne();
      };
      probe.onerror = completeOne;
      probe.src = candidate.thumb || candidate.url;
    });
  });
}
function scanStep(i){
  api('/api/scan-step', { i: i }).then(function(res){
    if (!res.ok){ alert(res.error || statusText('scanFailed')); goHome(); return; }
    if (res.item){
      state.items.push(res.item); preloadItem(res.item);
      if (state.iconSearchOnly || res.item.iconSearchOnly){
        prepareIconifyCandidatesInBrowser(res.item).then(function(){
          rankProgramCandidatesInBrowser(res.item).then(function(){ continueScanStep(res); });
        });
        return;
      }
    }
    continueScanStep(res);
  });
}
function continueScanStep(res){
  var pct = res.total ? Math.round(res.current/res.total*100) : 0;
  setLoadProgress(formatStr(statusText('scanProgress'), [res.current,res.total,res.label||'']), pct, res.current, res.total);
  if (res.done || res.current >= res.total){ preloadAround(0); enterItem(0); }
  else { setTimeout(function(){ scanStep(res.current); }, 0); }
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
  if (!it){ state.iconSearchOnly = !!state.scanIconSearchOnly; goReview(); return; }
  state.iconSearchOnly = !!state.scanIconSearchOnly || !!it.iconSearchOnly;
  if (!state.picks[it.index]) state.picks[it.index] = { game:1, cover:1 };
  if (it.remembered && it.savedUrl) applyRememberedCover(it);
  if (state.iconSearchOnly) {
    // Batch auto-match: first pass chooses the best-ranked software icon and
    // proceeds to the full review grid. Only explicitly selected items open
    // this item editor; it shows SGDB icon alternatives or manual image search.
    if (state.editReturnToReview) {
      // Program edits always open the combined live image-result studio.
      // The old path only showed SteamGridDB covers when it found a weak match.
      openGoogleCustom(false);
      return;
    }
    if (it.sections && it.sections.length && it.sections[0].covers && it.sections[0].covers.length) {
      if (!state.picks[it.index]) state.picks[it.index] = { game:1, cover:1 };
      else { state.picks[it.index].game = 1; state.picks[it.index].cover = 1; }
      updateAutoBanner(it.sections[0].gameName || it.name);
    } else {
      it.noAutoIcon = true;
      delete state.picks[it.index];
      updateAutoBanner(it.name + ' (' + statusText('notAutoMatched') + ')');
    }
    if (state.pos + 1 >= state.items.length) { goReview(); }
    else { setTimeout(function(){ enterItem(state.pos+1); }, 40); }
    return;
  }

  // Skip already-done: if the user chose to reuse memory and this game
  // has a remembered cover, apply it and move on without asking.
  if (state.useMemory && !state.editReturnToReview && it.remembered && it.savedUrl){
    if (state.autoAll){ updateAutoBanner((it.savedGameName || it.name) + ' (' + statusText('savedSuffix') + ')'); }
    if (state.pos + 1 >= state.items.length){ goReview(); }
    else { setTimeout(function(){ enterItem(state.pos+1); }, 60); }
    return;
  }

  if (state.autoAll && !state.editReturnToReview){
    var noArt = (!it.sections || !it.sections.length);
    // Permissive: accept the top match (or a placeholder when there is
    // no artwork at all). Mistakes are fixable later via Change Icons.
    if (noArt || it.autoConfident){
      state.picks[it.index] = { game:1, cover:1 };
      updateAutoBanner(noArt ? (it.name + ' (' + statusText('placeholderSuffix') + ')') : it.sections[0].gameName);
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
  $('loadingMsg').textContent = statusText('autoLoading');
  $('loadDetail').textContent = statusText('autoDetail');
  $('loadFill').style.width = '0%';
  $('autoFeed').innerHTML = '';
  setTimeout(function(){ enterItem(state.pos); }, 300);
}
function updateAutoBanner(name){
  var pct = state.items.length ? Math.round((state.pos+1)/state.items.length*100) : 0;
  $('loadFill').style.width = pct + '%';
  $('loadDetail').textContent = formatStr(statusText('matchingProgress'), [state.pos+1,state.items.length]);
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
  if (state.autoAll){ $('autoBanner').innerHTML = i18n[currentLang].autoBannerText; }
  var tc = i18n[currentLang];
  $('confirmTitle').textContent = state.iconSearchOnly
    ? ((screenI18n[currentLang] || screenI18n.en).iconReviewTitle)
    : (state.autoAll ? tc.confirmAutoTitle : tc.confirmTitle);
  $('confirmShortcut').textContent = formatStr(tc.shortcutProgress, [state.pos+1, state.items.length, it.name]);
  $('confirmCover').src = cover ? cover.thumb : '';
  $('confirmGame').textContent = sec.gameName;
  var confirmHint = document.querySelector('#step-confirm .hint');
  if (confirmHint && state.iconSearchOnly) confirmHint.textContent = (screenI18n[currentLang] || screenI18n.en).iconSearchHint;
  var wrongGameButton = document.querySelector('#step-confirm button.g-bad');
  if (wrongGameButton) {
    var hasAlternatives = !!(it.candidateGames && it.candidateGames.length > 0);
    wrongGameButton.style.display = (state.iconSearchOnly && !hasAlternatives) ? 'none' : '';
    wrongGameButton.textContent = state.iconSearchOnly
      ? (screenI18n[currentLang] || screenI18n.en).altIconMatch
      : tc.btnWrongGame;
  }
  var autoChooseButton = document.querySelector('#step-confirm .auto-btn');
  if (autoChooseButton) autoChooseButton.style.display = state.iconSearchOnly ? 'none' : '';
  $('confirmYear').textContent = sec.year > 0 ? formatStr(tc.releasedYear, [sec.year]) : '';
  show('step-confirm');
  setNavFocus('confirmBtns', 0);
}

function renderNoArt(){
  var it = currentItem();
  $('noartShortcut').textContent = formatStr(i18n[currentLang].shortcutProgress, [state.pos+1, state.items.length, it.name]);
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
  stopCoverImageLoading();
  var it = currentItem();
  var pick = state.picks[it.index];
  var sec = it.sections[pick.game-1] || it.sections[0];
  var artworkTitle = document.querySelector('#step-artwork h2');
  if (artworkTitle) artworkTitle.textContent = state.iconSearchOnly
    ? (screenI18n[currentLang] || screenI18n.en).programIconTitle
    : i18n[currentLang].titleArtwork;
  $('artworkGame').textContent = sec.gameName + (sec.year>0?(' ('+sec.year+')'):'');
  var grid = $('artworkGrid'); grid.innerHTML = '';
  sec.covers.forEach(function(c,i){
    var d = document.createElement('div');
    d.className = 'tile' + (i===(pick.cover-1)?' sel':'');
    d.tabIndex = 0;
    var img = document.createElement('img');
    img.alt = sec.gameName + ' cover ' + (i+1);
    img.loading = 'lazy';
    img.decoding = 'async';
    img.className = 'cover-loading';
    img.dataset.coverSrc = String(c.thumb || c.url || '');
    img.dataset.coverPriority = i === (pick.cover-1) ? '100' : (i < 4 ? String(60-i) : '0');
    d.appendChild(img);
    d.onclick = function(){ pick.cover = i+1; acceptMatch(); };
    grid.appendChild(d);
  });
  state.focusIdx = pick.cover-1; show('step-artwork');
  setGallery(state.gallery);
  focusTiles('#artworkGrid');
  observeCoverImages(grid);
}

function showOtherMatches(){
  var it = currentItem();
  $('matchesShortcut').textContent = state.iconSearchOnly
    ? ((screenI18n[currentLang] || screenI18n.en).altIconResults + it.name)
    : formatStr(i18n[currentLang].whichGame, [it.name]);
  var matchTitle = document.querySelector('#step-matches h2');
  if (matchTitle) matchTitle.textContent = state.iconSearchOnly
    ? (screenI18n[currentLang] || screenI18n.en).altIconTitle
    : manualGameText('heading');
  var searchPanel = $('gameSearchPanel');
  if (searchPanel) searchPanel.style.display = state.iconSearchOnly ? 'none' : '';
  var searchInput = $('gameSearchInput');
  if (searchInput) searchInput.value = it.name || '';
  var searchStatus = $('gameSearchStatus');
  if (searchStatus) searchStatus.textContent = state.iconSearchOnly ? '' : manualGameText('prompt');

  var cands = it.candidateGames || [];
  if (!cands.length && it.sections && it.sections.length && Number(it.sections[0].gameId) > 0) {
    cands = [{ gameId:it.sections[0].gameId, gameName:it.sections[0].gameName, year:it.sections[0].year }];
  }
  renderGameCandidates(cands, cands.length ? manualGameText('initialMatches') : manualGameText('noResults'));
  state.focusIdx = 0;
  show('step-matches');
  focusTiles('#matchesGrid');
}

function renderGameCandidates(candidates, emptyMessage){
  var it = currentItem();
  var grid = $('matchesGrid');
  if (!grid || !it) return;
  grid.innerHTML = '';
  var list = Array.isArray(candidates) ? candidates : [];
  if (!list.length) {
    grid.textContent = emptyMessage || manualGameText('noResults');
    state.focusIdx = 0;
    return;
  }
  list.forEach(function(g){
    var d = document.createElement('div');
    d.className = 'tile game-match-tile';
    d.tabIndex = 0;
    d.setAttribute('role','button');
    var preview = document.createElement('div');
    preview.className = 'game-match-preview';
    preview.style.cssText = 'width:100%;aspect-ratio:1;border-radius:8px;background:var(--panel);display:flex;align-items:center;justify-content:center;color:var(--muted);font-size:.8rem;text-align:center;padding:8px;';
    preview.textContent = statusText('loadingCover');
    var title = document.createElement('div');
    title.style.cssText = 'font-size:.82rem;margin-top:6px;text-align:center;';
    title.textContent = String(g.gameName || 'Unknown game') + (Number(g.year)>0 ? ' (' + Number(g.year) + ')' : '');
    var meta = document.createElement('div');
    meta.style.cssText = 'color:var(--muted);font-size:.72rem;margin-top:4px;text-align:center;';
    meta.textContent = Number(g.score)>0 ? ('SteamGridDB · ' + Number(g.score) + '%') : 'SteamGridDB';
    d.appendChild(preview); d.appendChild(title); d.appendChild(meta);
    d.onclick = function(){ pickGame(it, g); };
    d.onkeydown = function(e){ if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); pickGame(it,g); } };
    grid.appendChild(d);

    if (Number(g.gameId) > 0) {
      api('/api/game-covers', { gameId:g.gameId }).then(function(res){
        if (res && res.ok && res.covers && res.covers.length) {
          g._covers = res.covers;
          var img = document.createElement('img');
          img.src = res.covers[0].thumb || res.covers[0].url;
          img.loading = 'lazy'; img.alt = String(g.gameName || 'Game cover');
          img.style.cssText = 'width:100%;aspect-ratio:1;object-fit:cover;border-radius:8px;';
          if (preview.parentNode) preview.replaceWith(img);
        }
      });
    } else { preview.textContent = 'No SteamGridDB cover preview'; }
  });
  state.focusIdx = 0;
}

function searchGameCandidates(){
  if (state.iconSearchOnly) return;
  var query = String(($('gameSearchInput') && $('gameSearchInput').value) || '').trim();
  var status = $('gameSearchStatus'), button = $('gameSearchButton');
  if (query.length < 2) {
    if (status) status.textContent = manualGameText('noResults');
    return;
  }
  if (status) status.textContent = manualGameText('searching');
  if (button) button.disabled = true;
  api('/api/search-games', { query:query }).then(function(res){
    if (!res || !res.ok) {
      if (status) status.textContent = (res && res.error === 'API_KEY_REQUIRED') ? manualGameText('needKey') : ((res && res.error) || manualGameText('failed'));
      renderGameCandidates([], '');
      return;
    }
    var candidates = res.candidates || [];
    if (status) status.textContent = candidates.length ? (candidates.length + ' · SteamGridDB') : manualGameText('noResults');
    renderGameCandidates(candidates, manualGameText('noResults'));
    focusTiles('#matchesGrid');
  }).catch(function(){
    if (status) status.textContent = manualGameText('failed');
    renderGameCandidates([], '');
  }).then(function(){ if (button) button.disabled = false; });
}

function useCustomGameTitle(){
  if (state.iconSearchOnly) return;
  var query = String(($('gameSearchInput') && $('gameSearchInput').value) || '').trim();
  if (query.length < 2) {
    if ($('gameSearchStatus')) $('gameSearchStatus').textContent = manualGameText('noResults');
    return;
  }
  var it = currentItem();
  if (!it) return;
  it.customGameName = query;
  state.customGameReturnToMatches = true;
  customSearchKind = 'game';
  openGoogleCustom(false);
}
function pickGame(it, g){
  // Set this game as the item's chosen section and go to artwork.
  it.customGameName = '';
  state.customGameReturnToMatches = false;
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
  state.iconSearchOnly = !!state.scanIconSearchOnly;
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
    var itemIsProgramIcon = !!(state.scanIconSearchOnly || it.iconSearchOnly);
    var previewLabel = sec ? sec.gameName : (itemIsProgramIcon ? statusText('notAutoMatched') : statusText('placeholderLabel'));
    el.innerHTML = img +
      '<div style="font-size:.78rem;margin-top:6px;text-align:center;">'+it.name+
      '<div style="color:var(--muted)">'+previewLabel+'</div></div>';
    // Click anywhere on the tile to toggle selection for changing.
    el.onclick = function(){ toggleReviewSelect(i, el); };
    el.onkeydown = function(e){ if (e.key==='Enter'){ toggleReviewSelect(i, el); } };
    if (!itemIsProgramIcon) {
      var changeGameButton = document.createElement('button');
      changeGameButton.type = 'button';
      changeGameButton.className = 'review-change-game';
      changeGameButton.textContent = manualGameText('changeGame');
      changeGameButton.onclick = function(e){
        e.preventDefault();
        e.stopPropagation();
        editFromReview([i]);
      };
      changeGameButton.onkeydown = function(e){ e.stopPropagation(); };
      el.appendChild(changeGameButton);
    }
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
      changeBtn.textContent = i18n[currentLang].btnChangeSel + ' (' + n + ')';
      changeBtn.disabled = false;
      changeBtn.classList.remove('ghost');
      changeBtn.classList.add('big-btn','btn-warn');
    }
    setNavFocus('reviewBtns', 0);
  } else {
    if (finishBtn){ finishBtn.style.display = ''; }
    if (changeBtn){
      changeBtn.textContent = i18n[currentLang].btnChangeSel;
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
  state.autoAll = false;
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

function applyPhaseTitle(phase){
  var names = {
    download:'Downloading your cover art…',
    build:'Building crisp, multi-size icons…',
    backup:'Creating a safety restore point…',
    apply:'Applying icons to your shortcuts…',
    refresh:'Refreshing Windows Explorer…',
    complete:'Done! Your game shelf is ready.'
  };
  return names[phase] || 'Working…';
}

function updateApplyProgress(eventData){
  var phase = String(eventData.phase||'');
  var pct = Math.max(0,Math.min(100,Math.round(Number(eventData.percent)||0)));
  if (phase !== state._applyProgressPhase){
    state._applyProgressPhase = phase;
    fadeSwap($('loadingMsg'), applyPhaseTitle(phase));
  }
  $('loadFill').style.width = pct + '%';
  $('loadPercent').textContent = pct + '%';
  $('loadBar').setAttribute('aria-valuenow', String(pct));
  var total = Number(eventData.total)||0;
  var current = Number(eventData.current)||0;
  var counter = total > 0 ? (current + ' / ' + total + ' · ' + pct + '%') : (eventData.status === 'complete' ? 'Complete' : 'In progress');
  if (eventData.item) counter += ' · ' + eventData.item;
  $('loadCounter').textContent = counter;
  var detail = String(eventData.label||'');
  if (eventData.status === 'failed'){
    if (phase === 'backup') detail += ' — no shortcut changes were applied because the safety restore point could not be created.';
    else detail += ' — this item failed; the operation will continue where possible.';
  } else if (eventData.status === 'complete' && eventData.item) detail += ' · ' + eventData.item;
  state._lastApplyProgress = eventData;
  $('loadDetail').textContent = detail;
}

function applyStepWithProgress(payload){
  return fetch('/api/apply-step', {
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body:JSON.stringify(payload||{})
  }).then(function(response){
    if (!response.ok) throw new Error('Apply request failed (HTTP ' + response.status + ').');
    if (!response.body || !response.body.getReader){
      return response.text().then(function(text){
        var finalEvent = null;
        text.split(/\r?\n/).forEach(function(line){
          if (!line.trim()) return;
          var eventData = JSON.parse(line);
          if (eventData.type === 'progress') updateApplyProgress(eventData);
          else if (eventData.type === 'complete') finalEvent = eventData;
        });
        if (!finalEvent) throw new Error('The server did not return a final progress result.');
        return finalEvent;
      });
    }
    var reader = response.body.getReader();
    var decoder = new TextDecoder();
    var buffered = '';
    var finalEvent = null;
    return new Promise(function(resolve,reject){
      function parseLine(line){
        if (!line || !line.trim()) return;
        var eventData = JSON.parse(line);
        if (eventData.type === 'progress') updateApplyProgress(eventData);
        else if (eventData.type === 'complete') finalEvent = eventData;
      }
      function readNext(){
        reader.read().then(function(result){
          buffered += decoder.decode(result.value, {stream:!result.done});
          var lines = buffered.split(/\r?\n/);
          buffered = lines.pop() || '';
          lines.forEach(parseLine);
          if (result.done){
            parseLine(buffered);
            if (finalEvent) resolve(finalEvent);
            else reject(new Error('The progress stream ended before the operation returned a result.'));
            return;
          }
          readNext();
        }).catch(reject);
      }
      readNext();
    });
  });
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
    var targetLabel = itemNoun(total !== 1);
    var ta = i18n[currentLang];
    var msg = formatStr(ta.applyMsg, [total, targetLabel]);
    if (dups.length){ msg += ' ' + formatStr(ta.applyDups, [dups.join(', ')]); }
    $('applyConfirmText').textContent = msg;
    show('step-confirm-apply');
    return;
  }
  state._applyConfirmed = false;
  setProgress(2);
  state._applyProgressPhase = '';
  setLoading(statusText('applyPreparing'), statusText('applyStarting'), 0);
  $('loadDetail').textContent = statusText('waitingForApply');
  $('autoFeed').innerHTML = '';
  var picks = state.items.map(function(it){
    var pick = state.picks[it.index] || { game:1, cover:1 };
    var sec = (it.sections && it.sections.length) ? (it.sections[pick.game-1] || it.sections[0]) : null;
    var cover = sec ? (sec.covers[pick.cover-1] || sec.covers[0]) : null;
    return {
      index: it.index,
      url: cover ? cover.url : '',
      gameId: sec ? sec.gameId : 0,
      gameName: sec ? sec.gameName : it.name,
      isProgramIcon: !!(state.scanIconSearchOnly || it.iconSearchOnly)
    };
  });
  api('/api/apply-begin', { picks: picks }).then(function(res){
    if (!res.ok){ goReview(); alert(res.error || statusText('applyFailed')); return null; }
    $('loadDetail').textContent = statusText('progressLive');
    return applyStepWithProgress({ i:0 });
  }).then(function(result){
    if (!result) return;
    if (!result.ok){
      $('loadingMsg').textContent = statusText('updateFailed');
      $('loadDetail').textContent = result.error || 'Check the application log and try again.';
      $('loadCounter').textContent = statusText('stopped');
      return;
    }
    var report = result.report || {};
    var totalResult = Number(report.total)||0;
    var updatedResult = Number(report.updated)||0;
    var failedResult = Number(report.failed)||0;
    var lastProgress = state._lastApplyProgress || {};
    var stoppedForSafety = lastProgress.phase === 'backup' && lastProgress.status === 'failed';
    if (stoppedForSafety){
      $('loadingMsg').textContent = statusText('updateStopped');
      $('loadCounter').textContent = statusText('noIconsChanged');
      $('loadDetail').textContent = statusText('restorePointFailed');
    } else {
      $('loadFill').style.width = '100%';
      $('loadPercent').textContent = '100%';
      $('loadBar').setAttribute('aria-valuenow', '100');
      $('loadCounter').textContent = failedResult > 0 ? (updatedResult + ' / ' + totalResult + ' ' + i18n[currentLang].statUpdated.toLowerCase() + ' · ' + failedResult + ' ' + i18n[currentLang].statFailed.toLowerCase()) : statusText('complete');
      $('loadingMsg').textContent = failedResult > 0 ? statusText('finishedIssues') : statusText('shelfReady');
      $('loadDetail').textContent = failedResult > 0 ? statusText('applyFinishedDetail') : statusText('applyComplete');
    }
    setTimeout(function(){ renderReport(result.report); }, 500);
  }).catch(function(error){
    $('loadingMsg').textContent = statusText('progressInterrupted');
    $('loadDetail').textContent = (error && error.message) ? error.message : 'The server did not return progress data. Check the application log.';
    $('loadCounter').textContent = statusText('checkStatus');
    alert(statusText('progressConnectionLost'));
  });
}

function renderReport(r){
  state.report = r;
  setProgress(3);
  var g = $('reportGrid'); g.innerHTML = '';
  var tr = i18n[currentLang];
  var stats = [
    [tr.statUpdated, r.updated, 'var(--good)', 'updated'],
    [tr.statMatched, r.matched, 'var(--accent2)', 'matched'],
    [tr.statPlaceholder, r.placeholder, 'var(--warn)', 'placeholder'],
    [tr.statSkipped, r.skipped, 'var(--muted)', 'skipped'],
    [tr.statFailed, r.failed, 'var(--bad)', 'failed']
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
  var ts = i18n[currentLang];
  var parts = [];
  parts.push(statCard(ts.miniProcessed, total));
  parts.push(statCard(ts.miniUpdated, done));
  parts.push(statCard(ts.miniSuccess, successRate + '%'));
  parts.push(statCard(ts.miniPlaceholders, r.placeholder || 0));
  box.innerHTML = '<div class="stats-title">' + ts.runAtGlance + '</div><div class="stats-row">' + parts.join('') + '</div>';
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
    var homeCount = document.querySelectorAll('.home-btn').length;
    if (e.key === 'ArrowRight'){ if (state.homeFocus + 1 < homeCount && state.homeFocus % 3 < 2) state.homeFocus++; focusHome(); e.preventDefault(); }
    else if (e.key === 'ArrowLeft'){ if (state.homeFocus > 0 && state.homeFocus % 3 > 0) state.homeFocus--; focusHome(); e.preventDefault(); }
    else if (e.key === 'ArrowDown'){ state.homeFocus = Math.min(homeCount-1, state.homeFocus+3); focusHome(); e.preventDefault(); }
    else if (e.key === 'ArrowUp'){ state.homeFocus = Math.max(0, state.homeFocus-3); focusHome(); e.preventDefault(); }
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
  currentPollId++; // Cancel any active dialog polling
  if (visible('step-custom')){
    if (state.customGameReturnToMatches) {
      state.customGameReturnToMatches = false;
      var customItem = currentItem();
      if (customItem) customItem.customGameName = '';
      showOtherMatches();
    } else if (state.iconSearchOnly) { cancelCustomIcon(); }
    else { renderConfirm(); }
    return;
  }
  if (visible('step-artwork') || visible('step-matches')){ renderConfirm(); return; }
  if (visible('step-confirm')){
    if (state.history.length){ state.pos = state.history.pop(); renderConfirm(); }
    else { goHome(); }
    return;
  }
  if (visible('step-review')){ enterItem(state.items.length-1); return; }
  if (visible('step-folder')){ goHome(); return; }
}


// ---- GOOGLE / YANDEX IMAGES / CUSTOM ICON STUDIO ----
var customImageObj = null;
var customFitMode = 'crop'; // 'crop' | 'contain' | 'stretch'
var customSearchKind = 'game'; // 'game' | 'program'
var customCropState = { zoom:1, crop:null, drag:null };

function resetCustomCropState(){
  customCropState.zoom=1;customCropState.crop=null;customCropState.drag=null;
  var label=$('customZoomLabel');if(label)label.textContent='100%';
}
function ensureCustomCropSelection(){
  if(!customImageObj||customCropState.crop)return;
  var iw=customImageObj.naturalWidth||customImageObj.width,ih=customImageObj.naturalHeight||customImageObj.height;
  var side=Math.max(1,Math.min(iw,ih)*.72);
  customCropState.crop={x:(iw-side)/2,y:(ih-side)/2,size:side};
}
function getCustomCropGeometry(){
  var canvas=$('customSourceCanvas');if(!canvas||!customImageObj)return null;
  var iw=customImageObj.naturalWidth||customImageObj.width,ih=customImageObj.naturalHeight||customImageObj.height;
  ensureCustomCropSelection();
  if(customCropState.drag&&customCropState.drag.geometry)return customCropState.drag.geometry;
  var crop=customCropState.crop,scale=Math.min(canvas.width/iw,canvas.height/ih)*customCropState.zoom;
  var cx=crop.x+crop.size/2,cy=crop.y+crop.size/2;
  return {x:canvas.width/2-cx*scale,y:canvas.height/2-cy*scale,scale:scale,iw:iw,ih:ih};
}
function renderCustomCropStage(){
  var canvas=$('customSourceCanvas');if(!canvas)return;
  var ctx=canvas.getContext('2d'),W=canvas.width,H=canvas.height;
  ctx.clearRect(0,0,W,H);ctx.fillStyle='#0b1019';ctx.fillRect(0,0,W,H);
  if(!customImageObj){
    ctx.fillStyle='rgba(180,195,220,.65)';ctx.font='18px Segoe UI,sans-serif';ctx.textAlign='center';
    ctx.fillText('Load an image to select a crop area',W/2,H/2);return;
  }
  ensureCustomCropSelection();
  var g=getCustomCropGeometry(),crop=customCropState.crop;
  ctx.imageSmoothingEnabled=true;ctx.imageSmoothingQuality='high';
  ctx.drawImage(customImageObj,g.x,g.y,g.iw*g.scale,g.ih*g.scale);
  var rx=g.x+crop.x*g.scale,ry=g.y+crop.y*g.scale,side=crop.size*g.scale;
  ctx.fillStyle='rgba(4,8,15,.58)';
  ctx.fillRect(0,0,W,Math.max(0,ry));ctx.fillRect(0,ry,Math.max(0,rx),side);
  ctx.fillRect(rx+side,ry,Math.max(0,W-rx-side),side);ctx.fillRect(0,ry+side,W,Math.max(0,H-ry-side));
  ctx.save();ctx.strokeStyle='#7dd3fc';ctx.lineWidth=3;ctx.setLineDash([9,5]);ctx.strokeRect(rx,ry,side,side);
  ctx.setLineDash([]);ctx.strokeStyle='rgba(255,255,255,.82)';ctx.lineWidth=1;
  for(var n=1;n<=2;n++){var off=side*n/3;ctx.beginPath();ctx.moveTo(rx+off,ry);ctx.lineTo(rx+off,ry+side);ctx.stroke();ctx.beginPath();ctx.moveTo(rx,ry+off);ctx.lineTo(rx+side,ry+off);ctx.stroke();}
  var handle=Math.max(7,Math.min(12,side*.025));
  [[rx,ry],[rx+side,ry],[rx,ry+side],[rx+side,ry+side]].forEach(function(pt){
    ctx.beginPath();ctx.arc(pt[0],pt[1],handle,0,Math.PI*2);ctx.fillStyle='#eaf7ff';ctx.fill();ctx.strokeStyle='#0284c7';ctx.lineWidth=2;ctx.stroke();
  });
  ctx.restore();
  var zoom=$('customZoomLabel');if(zoom)zoom.textContent=Math.round(customCropState.zoom*100)+'%';
}
function customCropPointerPoint(e){
  var canvas=$('customSourceCanvas'),rect=canvas.getBoundingClientRect();
  return {x:(e.clientX-rect.left)*canvas.width/rect.width,y:(e.clientY-rect.top)*canvas.height/rect.height};
}
function customCropPointToSource(point,g){return {x:(point.x-g.x)/g.scale,y:(point.y-g.y)/g.scale};}
function clampCropValue(value,min,max){return Math.max(min,Math.min(max,value));}
function onCustomCropPointerDown(e){
  if(!customImageObj||!visible('step-custom'))return;
  var canvas=$('customSourceCanvas'),point=customCropPointerPoint(e),g=getCustomCropGeometry(),c=customCropState.crop;
  if(!g)return;
  var src=customCropPointToSource(point,g);
  if(src.x<0||src.y<0||src.x>g.iw||src.y>g.ih)return;
  var inside=src.x>=c.x&&src.x<=c.x+c.size&&src.y>=c.y&&src.y<=c.y+c.size;
  customCropState.drag={mode:inside?'move':'draw',geometry:g,start:src,origin:{x:c.x,y:c.y,size:c.size}};
  try{canvas.setPointerCapture(e.pointerId);}catch(err){}
  e.preventDefault();
}
function onCustomCropPointerMove(e){
  var drag=customCropState.drag;if(!drag||!customImageObj)return;
  var point=customCropPointerPoint(e),src=customCropPointToSource(point,drag.geometry),iw=drag.geometry.iw,ih=drag.geometry.ih;
  if(drag.mode==='move'){
    var size=drag.origin.size;
    customCropState.crop={x:clampCropValue(drag.origin.x+src.x-drag.start.x,0,iw-size),y:clampCropValue(drag.origin.y+src.y-drag.start.y,0,ih-size),size:size};
  }else{
    var dx=src.x-drag.start.x,dy=src.y-drag.start.y,side=Math.min(Math.abs(dx),Math.abs(dy));
    if(side<4)return;
    var x=dx>=0?drag.start.x:drag.start.x-side,y=dy>=0?drag.start.y:drag.start.y-side;
    x=clampCropValue(x,0,iw);y=clampCropValue(y,0,ih);side=Math.min(side,iw-x,ih-y);
    if(side<4)return;
    customCropState.crop={x:x,y:y,size:side};customFitMode='crop';
    ['Crop','Contain','Stretch'].forEach(function(m){var b=$('fit'+m);if(b)b.classList.toggle('active',m.toLowerCase()==='crop');});
  }
  renderCustomCanvas();e.preventDefault();
}
function onCustomCropPointerUp(e){
  if(!customCropState.drag)return;
  customCropState.drag=null;renderCustomCanvas();
  try{$('customSourceCanvas').releasePointerCapture(e.pointerId);}catch(err){}
  e.preventDefault();
}
function zoomCustomCrop(direction){
  if(!customImageObj)return;
  var canvas=$('customSourceCanvas'),iw=customImageObj.naturalWidth||customImageObj.width,ih=customImageObj.naturalHeight||customImageObj.height;
  ensureCustomCropSelection();
  var c=customCropState.crop,cx=c.x+c.size/2,cy=c.y+c.size/2;
  var base=Math.min(canvas.width/iw,canvas.height/ih),displaySide=c.size*base*customCropState.zoom;
  customCropState.zoom=clampCropValue(customCropState.zoom+(direction>0?.25:-.25),1,4);
  var size=clampCropValue(displaySide/(base*customCropState.zoom),Math.min(24,Math.min(iw,ih)),Math.min(iw,ih));
  customCropState.crop={x:clampCropValue(cx-size/2,0,iw-size),y:clampCropValue(cy-size/2,0,ih-size),size:size};
  renderCustomCanvas();
}
function resetCustomCrop(){
  if(!customImageObj)return;
  customCropState.zoom=1;customCropState.crop=null;customCropState.drag=null;ensureCustomCropSelection();setCustomFitMode('crop');
}
(function initCustomCropEvents(){
  var canvas=$('customSourceCanvas');if(!canvas)return;
  canvas.addEventListener('pointerdown',onCustomCropPointerDown);
  canvas.addEventListener('pointermove',onCustomCropPointerMove);
  canvas.addEventListener('pointerup',onCustomCropPointerUp);
  canvas.addEventListener('pointercancel',onCustomCropPointerUp);
  canvas.addEventListener('wheel',function(e){if(!customImageObj)return;e.preventDefault();zoomCustomCrop(e.deltaY<0?1:-1);},{passive:false});
})();

function openGoogleCustom(autoOpenSearch){
  var it = currentItem();
  if (!it) return;
  customSearchKind = state.iconSearchOnly ? 'program' : 'game';
  var customDisplayName = it.customGameName ? (it.name + ' → ' + it.customGameName) : it.name;
  $('customShortcutTitle').textContent = formatStr(i18n[currentLang].shortcutProgress, [state.pos+1, state.items.length, customDisplayName]);
  $('customUrlInput').value = '';
  $('customStatusMsg').textContent = state.iconSearchOnly
    ? 'Choose Google or Yandex Images, then drag the app icon here.'
    : 'Waiting for an image (drag & drop, Ctrl+V, URL, or local file)...';
  $('customApplyBtn').disabled = true;
  customImageObj = null;
  var cropEditor=$('customCropEditor');
  if(cropEditor)cropEditor.classList.remove('visible');
  resetCustomCropState();
  clearCustomCanvas();
  show('step-custom');
  updateCustomSearchKindUi();
  if ($('onlineSearchStatus')) $('onlineSearchStatus').textContent = 'Choose Google or Yandex Images, then drag an image into the large drop area below.';
  // In app-icon-only mode, do not open tabs automatically: browser popup blockers may reject new tabs.
  if (autoOpenSearch !== false) {
    if (customSearchKind === 'program') openYandexSearch();
    else openGoogleSearch();
  }
}

function setCustomSearchKind(kind){
  customSearchKind = (kind === 'program') ? 'program' : 'game';
  updateCustomSearchKindUi();
  if ($('onlineSearchStatus')) {
    $('onlineSearchStatus').textContent = customSearchKind === 'program'
      ? 'Choose Google or Yandex Images, then drag the app icon into the drop area.'
      : 'Choose Google or Yandex Images, then drag the game artwork into the drop area.';
  }
}

function updateCustomSearchKindUi(){
  var gameBtn = $('customKindGame'), programBtn = $('customKindProgram');
  if (gameBtn) gameBtn.classList.toggle('active', customSearchKind === 'game');
  if (programBtn) programBtn.classList.toggle('active', customSearchKind === 'program');
}

function getCustomSearchQuery(){
  var it = currentItem();
  if (!it) return '';
  var name = String((customSearchKind === 'game' && it.customGameName) || it.name || '').trim();
  return customSearchKind === 'program'
    ? name + ' icon png high resolution'
    : name + ' game cover official box art high resolution square';
}

function prepareCustomDropTarget(provider){
  var zone=$('customDropZone');
  if(zone){
    zone.classList.add('drop-ready');
    zone.setAttribute('aria-label','Ready to receive an image from '+provider);
  }
  var status=$('onlineSearchStatus');
  if(status)status.textContent='Ready for '+provider+': drag an image from the new tab and drop it into the highlighted area here.';
  var hint=$('customSearchHint');
  if(hint)hint.textContent='The drop area is ready. Keep this app open, switch to the image-search tab, then drag the image back into the highlighted area. No scrolling is needed.';
}
function openGoogleSearch(){
  var q = encodeURIComponent(getCustomSearchQuery());
  if (q) { prepareCustomDropTarget('Google Images'); openUrl('https://www.google.com/search?tbm=isch&q=' + q); }
}
function openYandexSearch(){
  var q = encodeURIComponent(getCustomSearchQuery());
  if (q) { prepareCustomDropTarget('Yandex Images'); openUrl('https://yandex.com/images/search?text=' + q); }
}
// Backwards-compatible name used by existing buttons in other screens.
function reopenGoogleSearch(){ openGoogleSearch(); }

// Manual image search stays in the user's browser; the editor accepts drag & drop, paste and local files.

function clearCustomCanvas(){
  var c=$('customCanvas');if(c){var ctx=c.getContext('2d');ctx.clearRect(0,0,c.width,c.height);}
  var source=$('customSourceCanvas');if(source){var sx=source.getContext('2d');sx.clearRect(0,0,source.width,source.height);renderCustomCropStage();}
}
function setCustomFitMode(mode){
  customFitMode=mode;
  ['Crop','Contain','Stretch'].forEach(function(m){var b=$('fit'+m);if(b)b.classList.toggle('active',m.toLowerCase()===mode);});
  if(customImageObj)renderCustomCanvas();
}
function renderCustomCanvas(){
  var c=$('customCanvas');
  if(!c||!customImageObj){renderCustomCropStage();return;}
  var ctx=c.getContext('2d'),W=c.width,H=c.height;
  ctx.clearRect(0,0,W,H);
  var iw=customImageObj.naturalWidth||customImageObj.width,ih=customImageObj.naturalHeight||customImageObj.height;
  if(!iw||!ih)return;
  if(customFitMode==='stretch')ctx.drawImage(customImageObj,0,0,W,H);
  else if(customFitMode==='contain'){
    var scale=Math.min(W/iw,H/ih),dw=Math.round(iw*scale),dh=Math.round(ih*scale);
    var dx=Math.round((W-dw)/2),dy=Math.round((H-dh)/2);
    ctx.drawImage(customImageObj,0,0,iw,ih,dx,dy,dw,dh);
  }else{
    ensureCustomCropSelection();
    var crop=customCropState.crop;
    ctx.drawImage(customImageObj,crop.x,crop.y,crop.size,crop.size,0,0,W,H);
  }
  $('customApplyBtn').disabled=false;
  var qualityHint=(iw<256||ih<256)?statusText('imageQualityLow'):statusText('imageQualityHigh');
  $('customStatusMsg').textContent=formatStr(statusText('imageReady'),[iw,ih,qualityHint]);
  if($('onlineSearchStatus')&&customSearchKind==='program')$('onlineSearchStatus').textContent=formatStr(statusText('imageLoaded'),[iw,ih]);
  renderCustomCropStage();
}
function loadDataUrlIntoCustomCanvas(dataUrl,onReady,onError){
  var img=new Image();
  img.onload=function(){
    customImageObj=img;
    var cropEditor=$('customCropEditor');
    if(cropEditor)cropEditor.classList.add('visible');
    resetCustomCropState();setCustomFitMode('crop');renderCustomCanvas();
    if(typeof onReady==='function')onReady();
  };
  img.onerror=function(){
    $('customStatusMsg').textContent=statusText('imageDecodeError');
    if(typeof onError==='function')onError();
  };
  img.src=dataUrl;
}

function readBlobIntoCustomCanvas(blob){
  if (!blob) return;
  if (blob.type && blob.type.indexOf('image/') !== 0){
    $('customStatusMsg').textContent = statusText('notImage');
    return;
  }
  $('customStatusMsg').textContent = statusText('readingImage');
  var reader = new FileReader();
  reader.onload = function(e){ loadDataUrlIntoCustomCanvas(e.target.result); };
  reader.onerror = function(){ $('customStatusMsg').textContent = statusText('fileReadError'); };
  reader.readAsDataURL(blob);
}

function triggerCustomFile(){
  var inp = $('customFileInput');
  if (inp) { inp.value = ''; inp.click(); }
}
function handleCustomFileSelect(e){
  var files = e.target.files;
  if (files && files.length > 0) readBlobIntoCustomCanvas(files[0]);
}

function extractGoogleImgUrl(rawUrl){
  if (!rawUrl) return '';
  rawUrl = String(rawUrl).trim();
  if (rawUrl.indexOf('//') === 0) rawUrl = 'https:' + rawUrl;
  try {
    var u = new URL(rawUrl);
    // Google and Yandex image-result links can carry the original image URL
    // in different query parameters. Prefer that original over the results page.
    var keys = ['imgurl','img_url','image_url','mediaurl','url'];
    for (var i=0; i<keys.length; i++){
      var v = u.searchParams.get(keys[i]);
      if (v && /^https?:\/\//i.test(v) && v !== rawUrl) return v;
    }
  } catch(e){}
  return rawUrl;
}

function loadCustomCandidates(candidates, index){
  candidates = candidates || [];
  index = index || 0;
  while (index < candidates.length){
    var candidate = String(candidates[index] || '').trim();
    index++;
    if (!candidate) continue;
    if (candidate.indexOf('data:image/') === 0){ loadDataUrlIntoCustomCanvas(candidate); return; }
    candidate = extractGoogleImgUrl(candidate);
    if (!/^https?:\/\//i.test(candidate)) continue;
    $('customUrlInput').value = candidate;
    $('customStatusMsg').textContent = formatStr(statusText('tryingImageSource'), [index,candidates.length]);
    (function(url, nextIndex){
      api('/api/fetch-remote-image', { url: url }).then(function(res){
        if (res && res.ok && res.dataUrl && res.dataUrl.indexOf('data:image/') === 0){
          loadDataUrlIntoCustomCanvas(res.dataUrl);
        } else {
          if (nextIndex < candidates.length) loadCustomCandidates(candidates, nextIndex);
          else $('customStatusMsg').textContent = (res && res.error) ? res.error : 'That link did not return an image. Try dragging the image itself or using Copy image → Ctrl+V.';
        }
      }).catch(function(){
        if (nextIndex < candidates.length) loadCustomCandidates(candidates, nextIndex);
        else $('customStatusMsg').textContent = statusText('imageFetchError');
      });
    })(candidate, index);
    return;
  }
  $('customStatusMsg').textContent = statusText('noImageUrl');
}

function loadCustomUrl(rawUrl, fallbackUrl){
  var candidates = [rawUrl, fallbackUrl].filter(function(v){ return !!v; });
  loadCustomCandidates(candidates, 0);
}
function loadCustomUrlInput(){
  var v = ($('customUrlInput').value || '').trim();
  if (v) loadCustomUrl(v, null);
}

function applyCustomCover(){
  var it = currentItem();
  var c = $('customCanvas');
  if (!it || !c || !customImageObj) return;
  $('customApplyBtn').disabled = true;
  $('customStatusMsg').textContent = statusText('savingCustomIcon');
  var pngDataUrl = c.toDataURL('image/png');
  api('/api/custom-cover', { name: it.name, dataUrl: pngDataUrl }).then(function(res){
    if (res && res.ok && res.url){
      if (!it.sections) it.sections = [];
      var chosenArtworkName = (customSearchKind === 'game' && it.customGameName) ? it.customGameName : it.name;
      var customSuffix = customSearchKind === 'program' ? ' (Custom App Icon)' : (it.customGameName ? ' (Custom Game Cover)' : ' (Custom Icon)');
      it.sections.unshift({
        gameId: 0,
        gameName: chosenArtworkName + customSuffix,
        year: 0,
        covers: [{ url: res.url, thumb: res.url, score: 100 }]
      });
      state.picks[it.index] = { game: 1, cover: 1 };
      it.customGameName = '';
      state.customGameReturnToMatches = false;
      acceptMatch();
    } else {
      $('customApplyBtn').disabled = false;
      $('customStatusMsg').textContent = (res && res.error) ? res.error : 'Failed to save custom icon.';
    }
  }).catch(function(){
    $('customApplyBtn').disabled = false;
    $('customStatusMsg').textContent = statusText('localServerError');
  });
}

function cancelCustomIcon(){
  if (state.customGameReturnToMatches) {
    state.customGameReturnToMatches = false;
    var customItem = currentItem();
    if (customItem) customItem.customGameName = '';
    showOtherMatches();
    return;
  }
  if (state.iconSearchOnly){
    // Skipped app shortcuts keep the app's normal placeholder behaviour.
    acceptMatch();
  } else {
    goBack();
  }
}

// Drag & Drop + Ctrl+V listeners. Images can be dropped onto the large drop zone
// OR directly on the square icon preview. Try alternate URLs from Yandex/Google
// when a provider supplies a thumbnail URL before its original image URL.
(function initCustomCoverEvents(){
  window.addEventListener('paste', function(e){
    if (!visible('step-custom')) return;
    var clip = e.clipboardData || (e.originalEvent && e.originalEvent.clipboardData) || window.clipboardData;
    var items = clip && clip.items ? clip.items : [];
    for (var i = 0; i < items.length; i++){
      if (items[i].type && items[i].type.indexOf('image/') === 0){
        e.preventDefault();
        readBlobIntoCustomCanvas(items[i].getAsFile());
        return;
      }
    }
    var txt = clip && clip.getData ? clip.getData('text') : '';
    if (txt && (/^https?:\/\//i.test(txt.trim()) || txt.trim().indexOf('data:image/') === 0)){
      e.preventDefault();
      $('customUrlInput').value = txt.trim();
      loadCustomUrl(txt.trim(), null);
    }
  });

  function handleDrop(e){
    e.preventDefault(); e.stopPropagation();
    if (e.currentTarget && e.currentTarget.classList) e.currentTarget.classList.remove('dragover');
    var dt = e.dataTransfer;
    if (!dt) return;
    if (dt.files && dt.files.length > 0){ readBlobIntoCustomCanvas(dt.files[0]); return; }

    var candidates = [];
    function addCandidate(v){
      if (!v) return;
      v = String(v).trim();
      if (!v || v.indexOf('javascript:') === 0 || v.indexOf('blob:') === 0) return;
      if (v.indexOf('//') === 0) v = 'https:' + v;
      if (v.indexOf('data:image/') === 0 || /^https?:\/\//i.test(v)) {
        v = extractGoogleImgUrl(v);
        if (candidates.indexOf(v) < 0) candidates.push(v);
      }
    }

    var html = dt.getData('text/html') || '';
    var uriText = dt.getData('text/uri-list') || '';
    var plainText = dt.getData('text/plain') || '';
    if (html){
      try {
        var doc = new DOMParser().parseFromString(html, 'text/html');
        var linkEls = doc.querySelectorAll('a[href]');
        linkEls.forEach(function(a){ addCandidate(a.getAttribute('href')); });
        var imgEls = doc.querySelectorAll('img');
        imgEls.forEach(function(img){
          addCandidate(img.getAttribute('data-original'));
          addCandidate(img.getAttribute('data-src'));
          addCandidate(img.getAttribute('src'));
          var srcset = img.getAttribute('srcset') || '';
          if (srcset) addCandidate(srcset.split(',').pop().trim().split(/\s+/)[0]);
        });
      } catch(err){}
    }
    uriText.split(/\r?\n/).forEach(function(line){ if (line && line.charAt(0) !== '#') addCandidate(line); });
    plainText.split(/\r?\n/).forEach(function(line){ addCandidate(line); });
    if (candidates.length){
      $('customStatusMsg').textContent = statusText('readingDroppedImage');
      loadCustomCandidates(candidates, 0);
    } else {
      $('customStatusMsg').textContent = statusText('dropReadError');
    }
  }

  var dz = $('customDropZone');
  var canvas = $('customCanvas');
  var preview = $('customPreviewDropZone');
  var zones = [dz, canvas, preview].filter(Boolean);
  zones.forEach(function(zone){
    ['dragenter','dragover'].forEach(function(ev){
      zone.addEventListener(ev, function(e){
        e.preventDefault(); e.stopPropagation();
        if (zone.classList) zone.classList.add('dragover');
        if (dz) dz.classList.add('dragover');
      });
    });
    ['dragleave','drop'].forEach(function(ev){
      zone.addEventListener(ev, function(e){
        if (ev === 'drop') handleDrop(e);
        else {
          e.preventDefault(); e.stopPropagation();
          if (zone.classList) zone.classList.remove('dragover');
          if (dz) dz.classList.remove('dragover');
        }
      });
    });
  });
})();

// boot
try { var z = parseFloat(localStorage.getItem('gis-zoom')); if (z >= 0.7 && z <= 1.7) state.zoom = z; } catch(e){}
try { state.gallery = (localStorage.getItem('gis-gallery') === '1'); } catch(e){}
applyZoom();
loadSavedTheme();
try {
  var savedLang = localStorage.getItem('gis-lang-v3');
  if (savedLang === 'ar' || savedLang === 'en' || savedLang === 'tr') { currentLang = savedLang; }
  else { currentLang = 'en'; }
} catch(e){ currentLang = 'en'; }
applyLang();
checkKey();
'@
}
