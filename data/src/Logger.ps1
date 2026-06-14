# ============================================================
#  Logger.ps1 - File + console logging with timestamps
# ============================================================

$script:LogFile = $null

function Initialize-Logger {
    param([Parameter(Mandatory)][string]$Root)

    $logDir = Join-Path $Root 'Logs'
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $script:LogFile = Join-Path $logDir 'Updater.log'

    Write-Log "============================================================" 'INFO' $true
    Write-Log "SteamGridDB Icon Updater Ultimate - session started" 'INFO' $true
    Write-Log "PowerShell $($PSVersionTable.PSVersion) on $([System.Environment]::OSVersion.VersionString)" 'INFO' $true
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','OK','WARN','ERROR','DEBUG')][string]$Level = 'INFO',
        [bool]$FileOnly = $false
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    if ($script:LogFile) {
        try {
            Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
        } catch { }
    }

    if (-not $FileOnly) {
        switch ($Level) {
            'OK'    { Write-Host $line -ForegroundColor Green }
            'WARN'  { Write-Host $line -ForegroundColor Yellow }
            'ERROR' { Write-Host $line -ForegroundColor Red }
            'DEBUG' { Write-Host $line -ForegroundColor DarkGray }
            default { Write-Host $line -ForegroundColor Gray }
        }
    }
}
