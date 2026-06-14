# ============================================================
#  Maintenance.ps1 - Cache management menu
#  View sizes and clean Cache (raw artwork), Icons (.ico cache),
#  old Backups and Logs.
# ============================================================

function Get-FolderStatsText {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) { return '0 files, 0.0 MB' }
    $files = @(Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue)
    $sum = ($files | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    $mb = [Math]::Round($sum / 1MB, 1)
    return "$($files.Count) files, $mb MB"
}

function Clear-FolderContents {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) { return 0 }
    $items = @(Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue)
    $removed = 0
    foreach ($item in $items) {
        try {
            Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
            $removed++
        } catch {
            Write-Log "Could not delete '$($item.FullName)': $($_.Exception.Message)" 'WARN'
        }
    }
    return $removed
}

function Invoke-CacheMenu {
    param([Parameter(Mandatory)][string]$Root)

    $cacheDir   = Join-Path $Root 'Cache'
    $iconsDir   = Join-Path $Root 'Icons'
    $backupsDir = Join-Path $Root 'Backups'
    $logsDir    = Join-Path $Root 'Logs'

    while ($true) {
        Write-Host ''
        Write-Host '  ------------------- CACHE MANAGEMENT -------------------' -ForegroundColor DarkCyan
        Write-Host "   Cache (raw artwork) : $(Get-FolderStatsText $cacheDir)"
        Write-Host "   Icons (.ico cache)  : $(Get-FolderStatsText $iconsDir)"
        Write-Host "   Backups             : $(Get-FolderStatsText $backupsDir)"
        Write-Host "   Logs                : $(Get-FolderStatsText $logsDir)"
        Write-Host '  ---------------------------------------------------------' -ForegroundColor DarkCyan
        Write-Host '   [1] Clear raw artwork cache (safe, will re-download when needed)'
        Write-Host '   [2] Clear icon cache (.ico files - next run rebuilds everything)'
        Write-Host '   [3] Clear both caches'
        Write-Host '   [4] Delete old backups (keeps the newest date only)'
        Write-Host '   [5] Clear log file'
        Write-Host '   [6] Clear saved cover choices (choices.json)'
        Write-Host '   [7] CLEAN EVERYTHING (icons, cache, backups, logs, choices, overrides)' -ForegroundColor Red
        Write-Host '   [0] Back to main menu'
        $choice = Read-KeyChoice -Prompt '  Choose:' -Allowed @('1','2','3','4','5','6','7','0') -Default '0'

        switch ($choice) {
            '1' {
                $n = Clear-FolderContents -Path $cacheDir
                Write-Log "Raw artwork cache cleared ($n item(s))." 'OK'
            }
            '2' {
                if (Read-YesNoKey -Prompt '  Shortcuts will keep working, but the next run rebuilds all icons. Continue?') {
                    Write-Host ''
                    Write-Host '  NOTE: shortcuts currently point to these .ico files.' -ForegroundColor Yellow
                    Write-Host '  Deleting them shows blank icons until the next update run.' -ForegroundColor Yellow
                    if (Read-YesNoKey -Prompt '  Are you sure?') {
                        $n = Clear-FolderContents -Path $iconsDir
                        Write-Log "Icon cache cleared ($n item(s)). Run an update to rebuild." 'OK'
                    }
                }
            }
            '3' {
                $n1 = Clear-FolderContents -Path $cacheDir
                Write-Log "Raw artwork cache cleared ($n1 item(s))." 'OK'
                Write-Host '  Icon cache requires confirmation (shortcuts point to these files).' -ForegroundColor Yellow
                if (Read-YesNoKey -Prompt '  Also clear icon cache?') {
                    $n2 = Clear-FolderContents -Path $iconsDir
                    Write-Log "Icon cache cleared ($n2 item(s))." 'OK'
                }
            }
            '4' {
                $dates = @(Get-ChildItem -Path $backupsDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
                if ($dates.Count -le 1) {
                    Write-Log 'Nothing to delete: one or zero backup folders exist.' 'INFO'
                } else {
                    $old = @($dates | Select-Object -Skip 1)
                    Write-Host "  Newest backup kept: $($dates[0].Name). To delete: $($old.Count) older folder(s)." -ForegroundColor Yellow
                    if (Read-YesNoKey -Prompt '  Continue?') {
                        $n = 0
                        foreach ($d in $old) {
                            try {
                                Remove-Item -Path $d.FullName -Recurse -Force -ErrorAction Stop
                                $n++
                            } catch {
                                Write-Log "Could not delete backup '$($d.Name)': $($_.Exception.Message)" 'WARN'
                            }
                        }
                        Write-Log "$n old backup folder(s) deleted." 'OK'
                    }
                }
            }
            '5' {
                $logFile = Join-Path $logsDir 'Updater.log'
                if (Test-Path $logFile) {
                    try {
                        Clear-Content -Path $logFile -ErrorAction Stop
                        Write-Log 'Log file cleared.' 'OK'
                    } catch {
                        Write-Log "Could not clear log: $($_.Exception.Message)" 'WARN'
                    }
                } else {
                    Write-Log 'No log file found.' 'INFO'
                }
            }
            '6' {
                $choicesPath = Join-Path $Root 'choices.json'
                if (Test-Path $choicesPath) {
                    if (Read-YesNoKey -Prompt '  Delete ALL saved manual cover choices? Rebuilds will go back to automatic scoring.') {
                        try {
                            Remove-Item -Path $choicesPath -Force -ErrorAction Stop
                            Write-Log 'Saved cover choices cleared.' 'OK'
                        } catch {
                            Write-Log "Could not delete choices.json: $($_.Exception.Message)" 'WARN'
                        }
                    }
                } else {
                    Write-Log 'No saved choices file found.' 'INFO'
                }
            }
            '7' {
                Write-Host ''
                Write-Host '  CLEAN EVERYTHING wipes Icons, Cache, Backups, Logs,' -ForegroundColor Red
                Write-Host '  choices.json and overrides.json for a fully fresh start.' -ForegroundColor Red
                Write-Host '  Your shortcuts keep their current icons until the next run,' -ForegroundColor Yellow
                Write-Host '  but the .ico files they point to will be gone (blank icons).' -ForegroundColor Yellow
                if (Read-YesNoKey -Prompt '  Wipe everything?') {
                    if (Read-YesNoKey -Prompt '  Are you absolutely sure? This cannot be undone.') {
                        $wiped = 0
                        foreach ($dir in @($cacheDir, $iconsDir, $backupsDir, $logsDir)) {
                            if (Test-Path $dir) {
                                try {
                                    Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                                    $wiped++
                                } catch {
                                    Write-Log "Could not remove '$dir': $($_.Exception.Message)" 'WARN'
                                }
                            }
                        }
                        foreach ($file in @((Join-Path $Root 'choices.json'), (Join-Path $Root 'overrides.json'))) {
                            if (Test-Path $file) {
                                try { Remove-Item -Path $file -Force -ErrorAction Stop; $wiped++ } catch {
                                    Write-Log "Could not remove '$file': $($_.Exception.Message)" 'WARN'
                                }
                            }
                        }
                        # Recreate the logs folder + a fresh session log
                        Initialize-Logger -Root $Root
                        Write-Log "CLEAN EVERYTHING done. Removed $wiped item(s). Fresh start ready." 'OK'
                    }
                }
            }
            '0' { return }
            default { }
        }
    }
}
