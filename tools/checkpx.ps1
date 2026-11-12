# The share of pixels in a region of a screenshot that are white (R, G, B > 200), red (R > 120, G and B < 90) or
# yellow (R > 180, G > 150, B < 90: SCAR's lit menu line), sampled every third pixel, printed with a dot.
# The region is given in a 1280x960 (4:3) window's pixels and mapped to the shot's size: the game's 2D layer keeps
# 4:3 and sits in the middle of a wider window (hud narrowing), so x is scaled about the centre by the height.
# Usage: powershell -ExecutionPolicy Bypass -File tools\checkpx.ps1 -Src shot.png -X 0 -Y 0 -W 100 -H 50 -Mode white
param([string]$Src, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Mode = "white")
Add-Type -AssemblyName System.Drawing
if (-not (Test-Path $Src)) { "missing"; exit 1 }
$b = [System.Drawing.Bitmap]::FromFile($Src)
$s = $b.Height / 960.0
$x0 = [int]($b.Width / 2.0 + ($X - 640) * $s); $y0 = [int]($Y * $s)
$x1 = [Math]::Min($b.Width, [int]($x0 + $W * $s)); $y1 = [Math]::Min($b.Height, [int]($y0 + $H * $s))
$x0 = [Math]::Max(0, $x0); $y0 = [Math]::Max(0, $y0)
$n = 0; $hit = 0
for ($yy = $y0; $yy -lt $y1; $yy += 3) {
    for ($xx = $x0; $xx -lt $x1; $xx += 3) {
        $c = $b.GetPixel($xx, $yy); $n++
        if ($Mode -eq "white" -and $c.R -gt 200 -and $c.G -gt 200 -and $c.B -gt 200) { $hit++ }
        if ($Mode -eq "yellow" -and $c.R -gt 180 -and $c.G -gt 150 -and $c.B -lt 90) { $hit++ }
        if ($Mode -eq "red" -and $c.R -gt 120 -and $c.G -lt 90 -and $c.B -lt 90) { $hit++ }
    }
}
$b.Dispose()
if ($n -eq 0) { "0.0000"; exit 0 }
($hit / $n).ToString("F4", [Globalization.CultureInfo]::InvariantCulture)
