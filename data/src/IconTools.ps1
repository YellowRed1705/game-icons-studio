# ============================================================
#  IconTools.ps1 - Multi-size .ico generation (16..256 px)
#  Styling: rounded corners, border, soft shadow (all optional)
#  Placeholder cover generator for games with no artwork.
#  Uses GDI+ (System.Drawing); writes PNG-compressed ICO
#  containers by hand, preserving full alpha transparency.
# ============================================================

Add-Type -AssemblyName System.Drawing -ErrorAction Stop

$script:IcoSizes = @(16, 32, 48, 64, 128, 256)

function Test-IsIcoFile {
    # Checks the magic bytes of a downloaded file (00 00 01 00 = ICO)
    param([Parameter(Mandatory)][string]$Path)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        return ($bytes.Length -gt 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 1 -and $bytes[3] -eq 0)
    } catch {
        return $false
    }
}

function Get-ContentAddressedIconCachePath {
    <#
        Returns the newest valid immutable ICO for a logical safe name.
        Legacy <name>.ico files are intentionally not treated as immutable
        cache entries because overwriting them can leave stale Explorer icons.
    #>
    param(
        [Parameter(Mandatory)][string]$IconsDir,
        [Parameter(Mandatory)][string]$SafeName
    )

    if (-not (Test-Path -LiteralPath $IconsDir -PathType Container)) { return $null }
    $prefix = $SafeName + '--'
    $files = @()
    try {
        $files = @(Get-ChildItem -LiteralPath $IconsDir -File -Force -ErrorAction Stop |
            Where-Object {
                $_.Extension -ieq '.ico' -and
                $_.BaseName.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)
            } |
            Sort-Object LastWriteTimeUtc -Descending)
    } catch { return $null }

    foreach ($file in $files) {
        if (Test-ValidIcoFile -Path $file.FullName) { return $file.FullName }
    }
    return $null
}

function Publish-ContentAddressedIco {
    <#
        Publishes a completed ICO under an immutable SHA-256-derived filename.
        Existing files are never overwritten. Repeated identical bytes reuse
        the same path, while different bytes always receive a different path.
    #>
    param(
        [Parameter(Mandatory)][string]$StagingPath,
        [Parameter(Mandatory)][string]$IconsDir,
        [Parameter(Mandatory)][string]$SafeName
    )

    if (-not (Test-ValidIcoFile -Path $StagingPath)) {
        throw "The staged ICO is missing or invalid: $StagingPath"
    }
    if (-not (Test-Path -LiteralPath $IconsDir -PathType Container)) {
        New-Item -ItemType Directory -Path $IconsDir -Force -ErrorAction Stop | Out-Null
    }

    $safe = Get-SafeFileName -Name $SafeName
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'icon' }
    $hash = (Get-FileHash -LiteralPath $StagingPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $shortHash = $hash.Substring(0,20)
    $candidates = @(
        (Join-Path $IconsDir ($safe + '--' + $shortHash + '.ico')),
        (Join-Path $IconsDir ($safe + '--' + $hash + '.ico'))
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            if ((Test-ValidIcoFile -Path $candidate) -and
                ((Get-FileHash -LiteralPath $candidate -Algorithm SHA256 -ErrorAction Stop).Hash -ieq $hash)) {
                Remove-Item -LiteralPath $StagingPath -Force -ErrorAction SilentlyContinue
                return $candidate
            }
            continue
        }

        try {
            [System.IO.File]::Move($StagingPath,$candidate)
            if (-not (Test-ValidIcoFile -Path $candidate)) { throw "Published ICO failed validation: $candidate" }
            $publishedHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($publishedHash -ine $hash) { throw "Published ICO hash verification failed: $candidate" }
            return $candidate
        } catch {
            # A concurrent process may have published the exact same bytes.
            if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and
                (Test-ValidIcoFile -Path $candidate)) {
                $existingHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256 -ErrorAction Stop).Hash
                if ($existingHash -ieq $hash) {
                    Remove-Item -LiteralPath $StagingPath -Force -ErrorAction SilentlyContinue
                    return $candidate
                }
            }
            if (-not (Test-Path -LiteralPath $StagingPath -PathType Leaf)) { throw }
        }
    }

    # Extremely unlikely short/full hash path conflict: keep the content
    # immutable and use a unique name rather than replacing any existing file.
    $uniquePath = Join-Path $IconsDir ($safe + '--' + $hash + '--' + [guid]::NewGuid().ToString('N') + '.ico')
    [System.IO.File]::Move($StagingPath,$uniquePath)
    if (-not (Test-ValidIcoFile -Path $uniquePath) -or
        (Get-FileHash -LiteralPath $uniquePath -Algorithm SHA256 -ErrorAction Stop).Hash -ine $hash) {
        throw "Published ICO failed final validation: $uniquePath"
    }
    return $uniquePath
}

function Set-FolderCustomIcon {
    <#
        Applies a content-addressed folder icon. It never overwrites a
        previously referenced folder_icon.ico, so Windows can distinguish
        a newly selected artwork by its changed IconResource path.
    #>
    param(
        [Parameter(Mandatory)][string]$FolderPath,
        [Parameter(Mandatory)][string]$IcoPath
    )

    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) { throw "Folder not found: $FolderPath" }
    if (-not (Test-ValidIcoFile -Path $IcoPath)) { throw "Icon file not found or invalid: $IcoPath" }

    $desktopIniPath = Join-Path $FolderPath 'desktop.ini'
    $stagingPath = Join-Path $FolderPath ('.gis-folder-icon-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        Copy-Item -LiteralPath $IcoPath -Destination $stagingPath -Force -ErrorAction Stop
        $publishedPath = Publish-ContentAddressedIco -StagingPath $stagingPath -IconsDir $FolderPath -SafeName 'folder_icon'
        $iconItem = Get-Item -LiteralPath $publishedPath -Force -ErrorAction Stop
        $iconItem.Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System

        $iconName = [System.IO.Path]::GetFileName($publishedPath)
        $desktopIniContent = "[.ShellClassInfo]" + [Environment]::NewLine + "IconResource=$iconName,0" + [Environment]::NewLine
        [System.IO.File]::WriteAllText($desktopIniPath,$desktopIniContent,[System.Text.Encoding]::Unicode)
        $iniItem = Get-Item -LiteralPath $desktopIniPath -Force -ErrorAction Stop
        $iniItem.Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System

        $folderItem = Get-Item -LiteralPath $FolderPath -Force -ErrorAction Stop
        $folderItem.Attributes = $folderItem.Attributes -bor [System.IO.FileAttributes]::ReadOnly

        try {
            if (-not ('Win32.Shell' -as [type])) {
                Add-Type -Namespace Win32 -Name Shell -MemberDefinition @'
[DllImport("shell32.dll", CharSet = CharSet.Unicode)]
public static extern void SHChangeNotify(int wEventId, uint uFlags, string dwItem1, IntPtr dwItem2);
'@
            }
            $flags = [uint32](0x0005 -bor 0x3000) # SHCNF_PATHW | SHCNF_FLUSHNOWAIT
            [Win32.Shell]::SHChangeNotify(0x00000800,$flags,$FolderPath,[IntPtr]::Zero) # ATTRIBUTES
            [Win32.Shell]::SHChangeNotify(0x00002000,$flags,$FolderPath,[IntPtr]::Zero) # UPDATEITEM
            [Win32.Shell]::SHChangeNotify(0x00001000,$flags,$FolderPath,[IntPtr]::Zero) # UPDATEDIR
        } catch {
            Write-Log "SHChangeNotify failed for folder '$FolderPath': $($_.Exception.Message)" 'WARN'
        }

        Write-Log "Folder icon set: $FolderPath -> $publishedPath" 'OK' $true
        return $publishedPath
    } catch {
        try { if (Test-Path -LiteralPath $stagingPath -PathType Leaf) { Remove-Item -LiteralPath $stagingPath -Force -ErrorAction SilentlyContinue } } catch { }
        throw
    }
}

function New-RoundedRectPath {
    param(
        [Parameter(Mandatory)][double]$X,
        [Parameter(Mandatory)][double]$Y,
        [Parameter(Mandatory)][double]$Width,
        [Parameter(Mandatory)][double]$Height,
        [Parameter(Mandatory)][double]$Radius
    )
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = [float]($Radius * 2)
    if ($d -le 0) {
        $path.AddRectangle((New-Object System.Drawing.RectangleF([float]$X, [float]$Y, [float]$Width, [float]$Height)))
        return $path
    }
    if ($d -gt $Width)  { $d = [float]$Width }
    if ($d -gt $Height) { $d = [float]$Height }
    $x = [float]$X; $y = [float]$Y; $w = [float]$Width; $h = [float]$Height
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function ConvertTo-GdiColor {
    # "#RRGGBB" -> System.Drawing.Color (falls back to white)
    param([string]$Hex)
    try {
        $h = $Hex.Trim().TrimStart('#')
        if ($h.Length -eq 6) {
            $r = [Convert]::ToInt32($h.Substring(0, 2), 16)
            $g = [Convert]::ToInt32($h.Substring(2, 2), 16)
            $b = [Convert]::ToInt32($h.Substring(4, 2), 16)
            return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
        }
    } catch { }
    return [System.Drawing.Color]::White
}

function New-StyledBitmap {
    <#
        Renders one icon frame:
        - center-crops the source to a square
        - optional soft drop shadow (sizes >= 48 px only)
        - optional rounded-corner clipping
        - optional border stroke
        Returns a 32bpp ARGB bitmap (caller must Dispose it).
    #>
    param(
        [Parameter(Mandatory)][System.Drawing.Image]$Source,
        [Parameter(Mandatory)][int]$Size,
        [int]$CornerRadiusPercent = 0,
        [int]$BorderWidthPercent = 0,
        [string]$BorderColor = '#FFFFFF',
        [bool]$ShadowEnabled = $false,
        [bool]$Contain = $false
    )

    $side = [Math]::Min($Source.Width, $Source.Height)
    $srcX = [int](($Source.Width  - $side) / 2)
    $srcY = [int](($Source.Height - $side) / 2)

    # Shadow needs breathing room around the cover
    $useShadow = ($ShadowEnabled -and $Size -ge 48)
    $margin = if ($useShadow) { [Math]::Max(2, [int]($Size * 0.06)) } else { 0 }
    $content = $Size - (2 * $margin)
    $radius = [Math]::Min([int]($content * $CornerRadiusPercent / 100.0), [int]($content / 2))

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)

        # ---- Soft shadow: layered translucent rounded rects ----
        if ($useShadow) {
            $layers = 4
            for ($i = $layers; $i -ge 1; $i--) {
                $grow = $i
                $alpha = [int](14 + (4 * ($layers - $i)))
                $sPath = New-RoundedRectPath -X ($margin - $grow + 1) -Y ($margin - $grow + 2) `
                    -Width ($content + 2 * $grow) -Height ($content + 2 * $grow) -Radius ($radius + $grow)
                $sBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alpha, 0, 0, 0))
                $g.FillPath($sBrush, $sPath)
                $sBrush.Dispose(); $sPath.Dispose()
            }
        }

        # ---- Cover, clipped to rounded rect ----
        $clipPath = New-RoundedRectPath -X $margin -Y $margin -Width $content -Height $content -Radius $radius
        $state = $g.Save()
        $g.SetClip($clipPath)
        if ($Contain) {
            # Fit the whole image inside the square (used for LOGO
            # artwork: wide transparent logos must never be cropped).
            $scale = [Math]::Min($content / [double]$Source.Width, $content / [double]$Source.Height)
            $dw = [Math]::Max(1, [int]($Source.Width * $scale))
            $dh = [Math]::Max(1, [int]($Source.Height * $scale))
            $dx = $margin + [int](($content - $dw) / 2)
            $dy = $margin + [int](($content - $dh) / 2)
            $destRect = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
            $srcRect  = New-Object System.Drawing.Rectangle(0, 0, $Source.Width, $Source.Height)
        } else {
            $destRect = New-Object System.Drawing.Rectangle($margin, $margin, $content, $content)
            $srcRect  = New-Object System.Drawing.Rectangle($srcX, $srcY, $side, $side)
        }
        $g.DrawImage($Source, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
        $g.Restore($state)

        # ---- Border stroke ----
        if ($BorderWidthPercent -gt 0) {
            $penWidth = [Math]::Max(1.0, $content * $BorderWidthPercent / 100.0)
            $pen = New-Object System.Drawing.Pen((ConvertTo-GdiColor $BorderColor), [float]$penWidth)
            $pen.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Inset
            $g.DrawPath($pen, $clipPath)
            $pen.Dispose()
        }

        $clipPath.Dispose()
    } finally {
        $g.Dispose()
    }
    return $bmp
}

function ConvertTo-Ico {
    <#
        Converts an image into a multi-size ICO (16..256 px) applying
        the configured style. Transparency preserved via PNG entries.
        A source that is already a valid .ico is copied through as-is
        (styling cannot be applied to prebuilt icons).
    #>
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$OutputPath,
        [int]$CornerRadiusPercent = 0,
        [int]$BorderWidthPercent = 0,
        [string]$BorderColor = '#FFFFFF',
        [bool]$ShadowEnabled = $false,
        [bool]$Contain = $false
    )

    if (-not (Test-Path $SourcePath)) { throw "Source image not found: $SourcePath" }

    if (Test-IsIcoFile -Path $SourcePath) {
        Copy-Item -Path $SourcePath -Destination $OutputPath -Force
        return $OutputPath
    }

    $source = $null
    $pngBlobs = @()

    try {
        $source = [System.Drawing.Image]::FromFile($SourcePath)

        foreach ($size in $script:IcoSizes) {
            $bmp = New-StyledBitmap -Source $source -Size $size `
                -CornerRadiusPercent $CornerRadiusPercent `
                -BorderWidthPercent $BorderWidthPercent `
                -BorderColor $BorderColor `
                -ShadowEnabled $ShadowEnabled `
                -Contain $Contain
            try {
                $ms = New-Object System.IO.MemoryStream
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $pngBlobs += ,@{ Size = $size; Data = $ms.ToArray() }
                $ms.Dispose()
            } finally {
                $bmp.Dispose()
            }
        }
    } catch {
        throw "Image conversion failed for '$SourcePath': $($_.Exception.Message)"
    } finally {
        if ($source) { $source.Dispose() }
    }

    # ---- Write the ICO container manually ----
    $fs = $null
    $writer = $null
    try {
        $fs = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $writer = New-Object System.IO.BinaryWriter($fs)

        $count = $pngBlobs.Count
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]$count)

        $offset = 6 + (16 * $count)
        foreach ($blob in $pngBlobs) {
            $dim = if ($blob.Size -ge 256) { [byte]0 } else { [byte]$blob.Size }
            $writer.Write([byte]$dim)
            $writer.Write([byte]$dim)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$blob.Data.Length)
            $writer.Write([UInt32]$offset)
            $offset += $blob.Data.Length
        }
        foreach ($blob in $pngBlobs) {
            $writer.Write($blob.Data)
        }
    } catch {
        throw "Failed to write ICO file '$OutputPath': $($_.Exception.Message)"
    } finally {
        if ($writer) { $writer.Dispose() }
        if ($fs) { $fs.Dispose() }
    }

    return $OutputPath
}

# ---------------- Placeholder cover generator ----------------

function Convert-HslToRgbColor {
    param([double]$H, [double]$S, [double]$L)

    $c = (1 - [Math]::Abs(2 * $L - 1)) * $S
    $hp = $H / 60.0
    $x = $c * (1 - [Math]::Abs(($hp % 2) - 1))
    $r1 = 0.0; $g1 = 0.0; $b1 = 0.0

    if     ($hp -ge 0 -and $hp -lt 1) { $r1 = $c; $g1 = $x; $b1 = 0 }
    elseif ($hp -ge 1 -and $hp -lt 2) { $r1 = $x; $g1 = $c; $b1 = 0 }
    elseif ($hp -ge 2 -and $hp -lt 3) { $r1 = 0;  $g1 = $c; $b1 = $x }
    elseif ($hp -ge 3 -and $hp -lt 4) { $r1 = 0;  $g1 = $x; $b1 = $c }
    elseif ($hp -ge 4 -and $hp -lt 5) { $r1 = $x; $g1 = 0;  $b1 = $c }
    else                              { $r1 = $c; $g1 = 0;  $b1 = $x }

    $m = $L - ($c / 2)
    $r = [int][Math]::Round(($r1 + $m) * 255)
    $g = [int][Math]::Round(($g1 + $m) * 255)
    $b = [int][Math]::Round(($b1 + $m) * 255)
    return [System.Drawing.Color]::FromArgb(255,
        [Math]::Max(0, [Math]::Min(255, $r)),
        [Math]::Max(0, [Math]::Min(255, $g)),
        [Math]::Max(0, [Math]::Min(255, $b)))
}

function New-PlaceholderCover {
    <#
        Generates a 512x512 PNG cover from a game name:
        deterministic hue from the name hash, dark diagonal gradient,
        accent bar, and the game title centered in bold white text.
        Returns the output path.
    #>
    param(
        [Parameter(Mandatory)][string]$GameName,
        [Parameter(Mandatory)][string]$OutputPath,
        [int]$Size = 512
    )

    # Deterministic hue from the game name
    $hash = 17
    foreach ($ch in $GameName.ToCharArray()) {
        $hash = (($hash * 31) + [int]$ch) -band 0x7FFFFFFF
    }
    $hue = [double]($hash % 360)

    $colTop    = Convert-HslToRgbColor -H $hue -S 0.55 -L 0.22
    $colBottom = Convert-HslToRgbColor -H (($hue + 45) % 360) -S 0.50 -L 0.12
    $colAccent = Convert-HslToRgbColor -H $hue -S 0.70 -L 0.55

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $font = $null
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

        # Diagonal gradient background
        $rect = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect, $colTop, $colBottom,
            [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)
        $g.FillRectangle($brush, $rect)
        $brush.Dispose()

        # Subtle oversized watermark letter
        $initial = ($GameName.Trim())[0].ToString().ToUpperInvariant()
        $wmFont = New-Object System.Drawing.Font('Segoe UI', [float]($Size * 0.85), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $wmBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(22, 255, 255, 255))
        $wmFormat = New-Object System.Drawing.StringFormat
        $wmFormat.Alignment = [System.Drawing.StringAlignment]::Center
        $wmFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
        $g.DrawString($initial, $wmFont, $wmBrush, (New-Object System.Drawing.RectangleF(0, 0, $Size, $Size)), $wmFormat)
        $wmFont.Dispose(); $wmBrush.Dispose(); $wmFormat.Dispose()

        # Accent bar
        $accBrush = New-Object System.Drawing.SolidBrush($colAccent)
        $g.FillRectangle($accBrush, [int]($Size * 0.42), [int]($Size * 0.30), [int]($Size * 0.16), 6)
        $accBrush.Dispose()

        # Title text: shrink font until it fits
        $pad = [int]($Size * 0.10)
        $layout = New-Object System.Drawing.RectangleF($pad, [int]($Size * 0.36), ($Size - 2 * $pad), [int]($Size * 0.42))
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center

        $fontSize = [int]($Size * 0.14)
        while ($fontSize -gt 18) {
            if ($font) { $font.Dispose() }
            $font = New-Object System.Drawing.Font('Segoe UI', [float]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $measured = $g.MeasureString($GameName, $font, [int]$layout.Width, $format)
            if ($measured.Height -le $layout.Height) { break }
            $fontSize -= 4
        }

        # Text shadow + text
        $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(140, 0, 0, 0))
        $shadowLayout = New-Object System.Drawing.RectangleF(($layout.X + 2), ($layout.Y + 3), $layout.Width, $layout.Height)
        $g.DrawString($GameName, $font, $shadowBrush, $shadowLayout, $format)
        $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
        $g.DrawString($GameName, $font, $textBrush, $layout, $format)
        $shadowBrush.Dispose(); $textBrush.Dispose(); $format.Dispose()

        $bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } catch {
        throw "Placeholder cover generation failed for '$GameName': $($_.Exception.Message)"
    } finally {
        if ($font) { $font.Dispose() }
        $g.Dispose()
        $bmp.Dispose()
    }
    return $OutputPath
}
