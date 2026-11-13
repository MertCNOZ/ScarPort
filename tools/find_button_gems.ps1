# Finds the game's Xbox button icons (the coloured gems: green A, red B, blue X, yellow Y) in texture dumps
# (textures\dumps, settings dump_textures = true) and prints where each is: one line per gem,
#   <dump key> <atlas w>x<atlas h> <button> <x> <y> <w> <h>
# A gem is a connected patch of solid pixels whose colour is saturated and of the button's hue; the dark round
# PlayStation-style icons, the PC key caps and the rest of the menu art beside them in the same atlases are not.
# tools\make_button_icons.ps1 draws the modern icons over these boxes. Only positions are read; nothing of the game's
# art is copied.
# Usage: powershell -ExecutionPolicy Bypass -File tools\find_button_gems.ps1 [dumps folder] > boxes.txt
param([string]$Dumps = (Join-Path (Split-Path $PSScriptRoot) "out\build\release\textures\dumps"))
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public static class Gems {
    public static List<string> Find(string path) {
        var found = new List<string>();
        using (var b = new Bitmap(path)) {
            int w = b.Width, h = b.Height;
            var px = new int[w * h];
            var data = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            System.Runtime.InteropServices.Marshal.Copy(data.Scan0, px, 0, w * h);
            b.UnlockBits(data);
            var seen = new bool[w * h];
            var stack = new Stack<int>();
            for (int i = 0; i < w * h; i++) {
                if (seen[i] || (px[i] >> 24 & 255) < 40) continue;
                int x0 = w, y0 = h, x1 = 0, y1 = 0, n = 0;
                double r = 0, g = 0, bl = 0, sat = 0;
                stack.Push(i);
                seen[i] = true;
                while (stack.Count > 0) {
                    int p = stack.Pop();
                    int x = p % w, y = p / w;
                    x0 = Math.Min(x0, x); x1 = Math.Max(x1, x); y0 = Math.Min(y0, y); y1 = Math.Max(y1, y);
                    int c = px[p];
                    int cr = c >> 16 & 255, cg = c >> 8 & 255, cb = c & 255;
                    r += cr; g += cg; bl += cb; n++;
                    sat += Math.Max(cr, Math.Max(cg, cb)) - Math.Min(cr, Math.Min(cg, cb));
                    for (int dy = -1; dy <= 1; dy++)
                        for (int dx = -1; dx <= 1; dx++) {
                            int nx = x + dx, ny = y + dy;
                            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                            int q = ny * w + nx;
                            if (seen[q] || (px[q] >> 24 & 255) < 40) continue;
                            seen[q] = true;
                            stack.Push(q);
                        }
                }
                int bw = x1 - x0 + 1, bh = y1 - y0 + 1;
                if (n < 40 || bw > 48 || bh > 48 || bw < 8 || bh < 8) continue;
                r /= n; g /= n; bl /= n; sat /= n;
                if (sat < 70) continue;
                string button = null;
                if (g > r * 1.15 && g > bl * 1.3) button = "A";
                else if (bl > r * 1.3 && bl > g * 1.05) button = "X";
                else if (r > 150 && g > 120 && bl < g * 0.6) button = "Y";
                else if (r > g * 1.5 && r > bl * 1.5) button = "B";
                if (button == null) continue;
                found.Add(String.Format("{0}x{1} {2} {3} {4} {5} {6}", w, h, button, x0, y0, bw, bh));
            }
        }
        return found;
    }
}
"@
foreach ($f in Get-ChildItem $Dumps -Filter *.png) {
    $parts = $f.BaseName.Split('_')
    if ($parts.Count -lt 3) { continue }
    $size = $parts[0].Split('x')
    if ([int]$size[0] -lt 64 -or [int]$size[1] -lt 64) { continue }
    foreach ($line in [Gems]::Find($f.FullName)) { "$($parts[1]) $line" }
}
