# Crops SCAR's race timer (top middle) and speed readout (bottom left) from window shots of a 1280x960 window, for
# reading them in a test: <name>_t.png and <name>_s.png beside each shot.
# Usage: powershell -ExecutionPolicy Bypass -File tools\crop_hud.ps1 acc_0 acc_1
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Names)
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Split-Path $PSScriptRoot) "out\ap\snaps"
foreach ($n in $Names) {
    $b = [System.Drawing.Bitmap]::FromFile((Join-Path $dir "$n.png"))
    $t = $b.Clone((New-Object System.Drawing.Rectangle 500, 60, 300, 70), $b.PixelFormat)
    $t.Save((Join-Path $dir "${n}_t.png"))
    $s = $b.Clone((New-Object System.Drawing.Rectangle 170, 820, 190, 70), $b.PixelFormat)
    $s.Save((Join-Path $dir "${n}_s.png"))
    $t.Dispose(); $s.Dispose(); $b.Dispose()
}
"cropped"
