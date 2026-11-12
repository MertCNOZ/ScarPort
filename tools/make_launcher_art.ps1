# Draws the launcher's placeholder art (no game or brand images): launcher\banner.jpg (graphite with red racing
# stripes and the project's name) and launcher\scarport.ico. Replace the banner with free to use art when there is
# one; the resource ids stay (launcher.rc).
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_launcher_art.ps1
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Split-Path $PSScriptRoot) "launcher"

# banner 1800 x 600
$w = 1800; $h = 600
$b = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = "AntiAlias"; $g.TextRenderingHint = "AntiAliasGridFit"
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point $w, $h), ([System.Drawing.Color]::FromArgb(34, 36, 42)), ([System.Drawing.Color]::FromArgb(10, 10, 12))
$g.FillRectangle($bg, 0, 0, $w, $h)
# slanted racing stripes
$red = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(205, 28, 32))
$dark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(120, 16, 20))
foreach ($s in @(@(980, 120, $red), @(1150, 60, $dark), @(1260, 40, $red))) {
    $x = $s[0]; $sw = $s[1]
    $pts = [System.Drawing.Point[]]@((New-Object System.Drawing.Point ($x + 260), 0), (New-Object System.Drawing.Point ($x + 260 + $sw), 0), (New-Object System.Drawing.Point ($x + $sw), $h), (New-Object System.Drawing.Point $x, $h))
    $g.FillPolygon($s[2], $pts)
}
# a faint grid of lines like a track map
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(28, 255, 255, 255)), 2
for ($y = 40; $y -lt $h; $y += 60) { $g.DrawLine($pen, 0, $y, $w, $y - 120) }
$f1 = New-Object System.Drawing.Font "Georgia", 120, ([System.Drawing.FontStyle]::Bold)
$f2 = New-Object System.Drawing.Font "Segoe UI", 34
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(240, 240, 244))
$grey = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(170, 172, 182))
$g.DrawString("SCAR", $f1, $white, 150, 150)
$g.DrawString("PC PORT", $f2, $grey, 162, 340)
$g.Dispose()
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 90L
$b.Save((Join-Path $dir "banner.jpg"), $codec, $ep)
$b.Dispose()

# icon: a red square with a white S, 256 x 256 PNG inside an .ico
$i = New-Object System.Drawing.Bitmap 256, 256
$g = [System.Drawing.Graphics]::FromImage($i)
$g.SmoothingMode = "AntiAlias"; $g.TextRenderingHint = "AntiAliasGridFit"
$g.Clear([System.Drawing.Color]::Transparent)
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = 48; $path.AddArc(8, 8, $r, $r, 180, 90); $path.AddArc(248 - $r, 8, $r, $r, 270, 90)
$path.AddArc(248 - $r, 248 - $r, $r, $r, 0, 90); $path.AddArc(8, 248 - $r, $r, $r, 90, 90); $path.CloseFigure()
$g.FillPath($red, $path)
$fs = New-Object System.Drawing.Font "Georgia", 150, ([System.Drawing.FontStyle]::Bold)
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = "Center"; $fmt.LineAlignment = "Center"
$g.DrawString("S", $fs, $white, (New-Object System.Drawing.RectangleF 0, 6, 256, 256), $fmt)
$g.Dispose()
$ms = New-Object System.IO.MemoryStream
$i.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$png = $ms.ToArray()
$out = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter $out
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)          # ICONDIR: one image
$bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)  # 256 x 256, no palette
$bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$png.Length); $bw.Write([uint32]22)
$bw.Write($png)
[System.IO.File]::WriteAllBytes((Join-Path $dir "scarport.ico"), $out.ToArray())
"banner.jpg and scarport.ico written"
