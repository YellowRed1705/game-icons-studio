# ============================================================
#  IconBackup.ps1 - Transaction snapshots and restore history
#  v6.32: transaction snapshots include custom-file shortcut creation.
# ============================================================

function Get-IconBackupRoot {
    param([Parameter(Mandatory)][string]$Root)
    return (Join-Path $Root 'Backups')
}

function Save-IconBackupManifest {
    param(
        [Parameter(Mandatory)][string]$TransactionFolder,
        [Parameter(Mandatory)]$Manifest
    )
    $path = Join-Path $TransactionFolder 'manifest.json'
    $tmp = "$path.tmp"
    $json = ConvertTo-Json -InputObject $Manifest -Depth 12
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $path) {
        Move-Item -LiteralPath $tmp -Destination $path -Force | Out-Null
    } else {
        Move-Item -LiteralPath $tmp -Destination $path | Out-Null
    }
}

function Add-IconBackupFile {
    param(
        [Parameter(Mandatory)][string]$OriginalPath,
        [Parameter(Mandatory)][string]$TransactionFolder,
        [Parameter(Mandatory)][int]$ItemNumber,
        [Parameter(Mandatory)][int]$FileNumber
    )
    $exists = Test-Path -LiteralPath $OriginalPath -PathType Leaf
    $attributes = 0
    if ($exists) {
        $item = Get-Item -LiteralPath $OriginalPath -Force -ErrorAction Stop
        $attributes = [int]$item.Attributes
    }
    $leaf = [System.IO.Path]::GetFileName($OriginalPath)
    if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = 'icon-file.bin' }
    $safeLeaf = Get-SafeFileName -Name $leaf
    $backupName = ('item-{0:D4}-file-{1:D2}-{2}' -f $ItemNumber,$FileNumber,$safeLeaf)
    $relative = Join-Path 'files' $backupName
    if ($exists) {
        $filesDir = Join-Path $TransactionFolder 'files'
        if (-not (Test-Path -LiteralPath $filesDir)) { New-Item -ItemType Directory -Path $filesDir -Force | Out-Null }
        Copy-Item -LiteralPath $OriginalPath -Destination (Join-Path $TransactionFolder $relative) -Force -ErrorAction Stop | Out-Null
    }
    return [ordered]@{
        OriginalPath = $OriginalPath
        Existed = [bool]$exists
        BackupFile = $relative
        Attributes = $attributes
    }
}

function New-IconBackupTransaction {
    <#
      Snapshots all targets before phase 3 creates ICO files. This is
      deliberately fail-closed: if any snapshot cannot be completed,
      the caller must stop before it changes any icon or overwrites ICOs.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Shortcuts,
        [Parameter(Mandatory)]$Resolutions,
        [int]$RetentionLimit = 50
    )

    $backupRoot = Get-IconBackupRoot -Root $Root
    if (-not (Test-Path -LiteralPath $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null }
    $id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $transactionFolder = Join-Path $backupRoot $id
    New-Item -ItemType Directory -Path $transactionFolder -Force | Out-Null

    $manifest = [ordered]@{
        SchemaVersion = 1
        Id = $id
        CreatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        AppVersion = '6.35'
        Label = 'Icon change transaction'
        RestoredAt = ''
        Items = @()
    }

    try {
        $itemNumber = 0
        foreach ($shortcut in @($Shortcuts)) {
            if ($null -eq $shortcut -or $shortcut.Status -eq 'Failed') { continue }
            $name = [string]$shortcut.NormalizedName
            if ([string]::IsNullOrWhiteSpace($name)) { $name = [string]$shortcut.Name }
            $key = [string]$shortcut.NormalizedName
            $resolution = $null
            if ($Resolutions.ContainsKey($key)) { $resolution = $Resolutions[$key] }
            if ($null -eq $resolution -or $resolution.Failed) { continue }

            $targetPath = [string]$shortcut.Path
            $isFolder = $false
            $isFileShortcut = ($shortcut.PSObject.Properties.Name -contains 'IsGeneratedFileShortcut' -and [bool]$shortcut.IsGeneratedFileShortcut)
            if ($shortcut.PSObject.Properties.Name -contains 'IsFolder') { $isFolder = [bool]$shortcut.IsFolder }
            else { $isFolder = Test-Path -LiteralPath $targetPath -PathType Container }
            $shortcutExisted = Test-Path -LiteralPath $targetPath -PathType Leaf

            $itemNumber++
            $entry = [ordered]@{
                Name = [string]$shortcut.Name
                TargetPath = $targetPath
                Type = $(if ($isFolder) { 'folder' } elseif ($isFileShortcut) { 'fileShortcut' } else { 'shortcut' })
                ShortcutExisted = [bool]$shortcutExisted
                PreviousIconLocation = ''
                PreviousFolderAttributes = 0
                FileBackups = @()
            }

            $filePaths = New-Object System.Collections.Generic.List[string]
            $fileNumber = 0
            if ($isFolder) {
                if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) { throw "Folder no longer exists: $targetPath" }
                $folderItem = Get-Item -LiteralPath $targetPath -Force -ErrorAction Stop
                $entry.PreviousFolderAttributes = [int]$folderItem.Attributes
                foreach ($filePath in @(
                    (Join-Path $targetPath 'desktop.ini'),
                    (Join-Path $targetPath 'folder_icon.ico'),
                    [string]$resolution.IcoPath
                )) {
                    if ([string]::IsNullOrWhiteSpace($filePath)) { continue }
                    $duplicate = $false
                    foreach ($existing in $filePaths) { if ([string]::Equals($existing,$filePath,[System.StringComparison]::OrdinalIgnoreCase)) { $duplicate = $true; break } }
                    if ($duplicate) { continue }
                    $filePaths.Add($filePath)
                }
            } else {
                if (-not $isFileShortcut -and -not $shortcutExisted) { throw "Shortcut no longer exists: $targetPath" }
                if ($shortcutExisted) {
                    $wsh = Get-WshShell
                    $lnk = $wsh.CreateShortcut($targetPath)
                    $entry.PreviousIconLocation = [string]$lnk.IconLocation
                }

                # File shortcuts are backed up as whole .lnk files; when the
                # companion did not exist before, the missing-file marker makes
                # Undo remove the newly created shortcut instead of leaving it.
                if ($isFileShortcut) { $filePaths.Add($targetPath) }
                if (-not [string]::IsNullOrWhiteSpace([string]$resolution.IcoPath)) { $filePaths.Add([string]$resolution.IcoPath) }
                $oldIcon = ([string]$entry.PreviousIconLocation -split ',')[0].Trim().Trim('"')
                if (-not [string]::IsNullOrWhiteSpace($oldIcon) -and [System.IO.Path]::GetExtension($oldIcon) -ieq '.ico' -and (Test-Path -LiteralPath $oldIcon -PathType Leaf)) {
                    $duplicate = $false
                    foreach ($existing in $filePaths) { if ([string]::Equals($existing,$oldIcon,[System.StringComparison]::OrdinalIgnoreCase)) { $duplicate = $true; break } }
                    if (-not $duplicate) { $filePaths.Add($oldIcon) }
                }
            }

            foreach ($filePath in $filePaths) {
                $fileNumber++
                $entry.FileBackups += Add-IconBackupFile -OriginalPath $filePath -TransactionFolder $transactionFolder -ItemNumber $itemNumber -FileNumber $fileNumber
            }
            $manifest.Items += $entry
            # Write after each item so an interrupted process still leaves a
            # recoverable manifest for everything captured so far.
            Save-IconBackupManifest -TransactionFolder $transactionFolder -Manifest $manifest
        }

        if (@($manifest.Items).Count -eq 0) {
            Remove-Item -LiteralPath $transactionFolder -Recurse -Force -ErrorAction SilentlyContinue
            return $null
        }
        Save-IconBackupManifest -TransactionFolder $transactionFolder -Manifest $manifest
        Prune-IconBackupTransactions -Root $Root -RetentionLimit $RetentionLimit -KeepId $id
        Write-Log "Created reversible icon backup '$id' for $(@($manifest.Items).Count) item(s)." 'OK' $true
        return [PSCustomObject]@{ Id = $id; Folder = $transactionFolder; Manifest = $manifest }
    } catch {
        try { Remove-Item -LiteralPath $transactionFolder -Recurse -Force -ErrorAction SilentlyContinue } catch { }
        throw "Could not create a complete icon backup. No icons were changed. $($_.Exception.Message)"
    }
}

function Prune-IconBackupTransactions {
    param(
        [Parameter(Mandatory)][string]$Root,
        [int]$RetentionLimit = 50,
        [string]$KeepId = ''
    )
    if ($RetentionLimit -le 0) { return } # 0 means unlimited history
    $folder = Get-IconBackupRoot -Root $Root
    if (-not (Test-Path -LiteralPath $folder)) { return }
    $transactions = @(Get-ChildItem -LiteralPath $folder -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'manifest.json') } |
        Sort-Object LastWriteTimeUtc -Descending)
    $kept = 0
    foreach ($transaction in $transactions) {
        if ($transaction.Name -eq $KeepId) { $kept++; continue }
        if ($kept -lt $RetentionLimit) { $kept++; continue }
        try { Remove-Item -LiteralPath $transaction.FullName -Recurse -Force -ErrorAction Stop }
        catch { Write-Log "Could not prune old restore point '$($transaction.Name)': $($_.Exception.Message)" 'WARN' }
    }
}

function Get-IconBackupTransactions {
    param([Parameter(Mandatory)][string]$Root, [int]$Limit = 100)
    $folder = Get-IconBackupRoot -Root $Root
    if (-not (Test-Path -LiteralPath $folder)) { return @() }
    $result = New-Object System.Collections.Generic.List[object]
    $directories = @(Get-ChildItem -LiteralPath $folder -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'manifest.json') } |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First ([Math]::Max(1,$Limit)))
    foreach ($dir in $directories) {
        try {
            $manifest = Get-Content -LiteralPath (Join-Path $dir.FullName 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $count = @($manifest.Items).Count
            if ($count -le 0) { continue }
            $result.Add([PSCustomObject]@{
                Id = [string]$manifest.Id
                CreatedAt = [string]$manifest.CreatedAt
                Label = 'Icon change transaction'
                ItemCount = $count
                RestoredAt = [string]$manifest.RestoredAt
            })
        } catch {
            Write-Log "Unreadable backup manifest '$($dir.Name)': $($_.Exception.Message)" 'WARN'
        }
    }
    return $result.ToArray()
}

function Restore-IconBackupFile {
    param(
        [Parameter(Mandatory)]$FileRecord,
        [Parameter(Mandatory)][string]$TransactionFolder
    )
    $target = [string]$FileRecord.OriginalPath
    if ([string]::IsNullOrWhiteSpace($target)) { throw 'Backup contains an empty target path.' }
    $parent = [System.IO.Path]::GetDirectoryName($target)
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "The original directory no longer exists: $parent" }

    if ([bool]$FileRecord.Existed) {
        $relative = [string]$FileRecord.BackupFile
        if ([string]::IsNullOrWhiteSpace($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)' -or -not $relative.StartsWith('files' + [System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unsafe or invalid internal backup path.'
        }
        $backupPath = [System.IO.Path]::GetFullPath((Join-Path $TransactionFolder $relative))
        $expectedPrefix = [System.IO.Path]::GetFullPath((Join-Path $TransactionFolder 'files') + [System.IO.Path]::DirectorySeparatorChar)
        if (-not $backupPath.StartsWith($expectedPrefix,[System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            throw 'The stored backup file is missing or invalid.'
        }
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            try { (Get-Item -LiteralPath $target -Force).Attributes = [System.IO.FileAttributes]::Normal } catch { }
        }
        Copy-Item -LiteralPath $backupPath -Destination $target -Force -ErrorAction Stop | Out-Null
        (Get-Item -LiteralPath $target -Force -ErrorAction Stop).Attributes = [System.IO.FileAttributes][int]$FileRecord.Attributes
    } else {
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            try { (Get-Item -LiteralPath $target -Force).Attributes = [System.IO.FileAttributes]::Normal } catch { }
            Remove-Item -LiteralPath $target -Force -ErrorAction Stop
        }
    }
}

function Restore-IconBackupTransaction {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][AllowEmptyString()][string]$Id)
    if ($Id -notmatch '^\d{8}-\d{6}-[a-fA-F0-9]{8}$') { return @{ ok = $false; error = 'Invalid restore-point ID.'; restoredCount = 0; failedCount = 0; failures = @() } }
    $transactionFolder = Join-Path (Get-IconBackupRoot -Root $Root) $Id
    $manifestPath = Join-Path $transactionFolder 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return @{ ok = $false; error = 'Restore point not found.'; restoredCount = 0; failedCount = 0; failures = @() } }

    try { $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { return @{ ok = $false; error = 'Restore point manifest is unreadable.'; restoredCount = 0; failedCount = 0; failures = @() } }

    $restored = 0
    $failures = New-Object System.Collections.Generic.List[string]
    foreach ($entry in @($manifest.Items)) {
        try {
            # Restore each original file (including prior managed ICO files) first.
            foreach ($file in @($entry.FileBackups)) {
                Restore-IconBackupFile -FileRecord $file -TransactionFolder $transactionFolder
            }

            if ([string]$entry.Type -eq 'shortcut' -or [string]$entry.Type -eq 'fileShortcut') {
                $path = [string]$entry.TargetPath
                $shouldRestoreLink = ([string]$entry.Type -eq 'shortcut') -or [bool]$entry.ShortcutExisted
                if ($shouldRestoreLink) {
                    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Shortcut no longer exists: $path" }
                    $wsh = Get-WshShell
                    $lnk = $wsh.CreateShortcut($path)
                    $lnk.IconLocation = [string]$entry.PreviousIconLocation
                    $lnk.Save()
                }
            } elseif ([string]$entry.Type -eq 'folder') {
                $path = [string]$entry.TargetPath
                if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "Folder no longer exists: $path" }
                (Get-Item -LiteralPath $path -Force -ErrorAction Stop).Attributes = [System.IO.FileAttributes][int]$entry.PreviousFolderAttributes
            } else {
                throw 'Unknown target type in restore point.'
            }
            $restored++
        } catch {
            $failures.Add("$([string]$entry.Name): $($_.Exception.Message)")
            Write-Log "Restore failed for '$([string]$entry.Name)': $($_.Exception.Message)" 'ERROR' $true
        }
    }

    $manifest.RestoredAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $manifest.RestoreResult = [ordered]@{ RestoredCount = $restored; FailedCount = $failures.Count }
    try { Save-IconBackupManifest -TransactionFolder $transactionFolder -Manifest $manifest } catch { }
    if ($restored -gt 0) { try { Update-ExplorerIcons } catch { } }

    $ok = ($failures.Count -eq 0 -and $restored -gt 0)
    $message = if ($ok) { "Restored $restored item(s) to their previous icon state." } else { "Restored $restored item(s); $($failures.Count) item(s) could not be restored." }
    return @{ ok = $ok; message = $message; restoredCount = $restored; failedCount = $failures.Count; failures = @($failures.ToArray()) }
}
