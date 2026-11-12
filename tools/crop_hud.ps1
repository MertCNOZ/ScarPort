# Crops SCAR's race timer (top middle) and speed readout (bottom left) from window shots, for reading them in a test:
# <name>_t.png and <name>_s.png beside each shot. Regions in 1280x960 (4:3) pixels, mapped like tools/checkpx.ps1.
# Usage: powershell -ExecutionPolicy Bypass -File tools\crop_hud.ps1 acc_0 acc_1
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Names)
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Split-Path $PSScriptRoot) "out\ap\snaps"
foreach ($n in $Names) {
    $b = [System.Drawing.Bitmap]::FromFile((Join-Path $dir "$n.png"))
    $k = $b.Height / 960.0
    $map = { param($x, $y, $w, $h) New-Object System.Drawing.Rectangle ([int]($b.Width / 2.0 + ($x - 640) * $k)), ([int]($y * $k)), ([int]($w * $k)), ([int]($h * $k)) }
    $t = $b.Clone((& $map 500 60 300 70), $b.PixelFormat)
    $t.Save((Join-Path $dir "${n}_t.png"))
    $s = $b.Clone((& $map 170 820 190 70), $b.PixelFormat)
    $s.Save((Join-Path $dir "${n}_s.png"))
    $t.Dispose(); $s.Dispose(); $b.Dispose()
}
"cropped"
