# Draws the "modern_buttons" texture pack: the game's Xbox button icons (the coloured A, B, X and Y gems in its menu
# atlases) as a modern Xbox controller's dark round buttons with coloured letters, drawn here from shapes and text.
# The atlases also hold the rest of the menus' art, so each image here is an overlay (<size>_<key>_overlay.png, see
# the SDK's texturedumper): the runtime draws it over the player's own copy of the texture when the game uses it, and
# the pack holds nothing of the game. Each gem's box is erased (alpha 1) and the new button drawn in it, at 4 times
# the atlas' size (as ui_upscale makes the atlas). The boxes are what tools\find_button_gems.ps1 found in the dumps.
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_button_icons.ps1 [out folder]
param([string]$Out = (Join-Path (Split-Path $PSScriptRoot) "packs\modern_buttons"))
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;

public static class Icons {
    static readonly Color Body = Color.FromArgb(255, 30, 31, 34);
    static readonly Color BodyLight = Color.FromArgb(255, 64, 66, 72);
    static readonly Color Rim = Color.FromArgb(255, 120, 122, 128);
    static readonly Color Label = Color.FromArgb(255, 238, 238, 240);
    static readonly Color Gold = Color.FromArgb(255, 246, 182, 50);
    static readonly Color GoldDark = Color.FromArgb(255, 150, 92, 18);

    public static Graphics Begin(Bitmap b) {
        Graphics g = Graphics.FromImage(b);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        g.CompositingQuality = CompositingQuality.HighQuality;
        return g;
    }

    static GraphicsPath Rounded(RectangleF r, float rad) {
        var p = new GraphicsPath();
        float d = rad * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    // text centred in r, as a filled path so it is smooth at any size
    static void Text(Graphics g, string s, RectangleF r, float size, Color c) {
        using (var fam = new FontFamily("Segoe UI"))
        using (var p = new GraphicsPath())
        using (var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center }) {
            p.AddString(s, fam, (int)FontStyle.Bold, size, new PointF(0, 0), StringFormat.GenericTypographic);
            RectangleF tb = p.GetBounds();
            using (var m = new Matrix()) {
                m.Translate(r.X + (r.Width - tb.Width) / 2 - tb.X, r.Y + (r.Height - tb.Height) / 2 - tb.Y);
                p.Transform(m);
            }
            using (var br = new SolidBrush(c)) g.FillPath(br, p);
        }
    }

    static void Body3D(Graphics g, GraphicsPath shape, RectangleF r, float rim) {
        using (var br = new LinearGradientBrush(new PointF(r.X, r.Y), new PointF(r.X, r.Bottom), BodyLight, Body))
            g.FillPath(br, shape);
        using (var pen = new Pen(Rim, rim)) g.DrawPath(pen, shape);
    }

    // A B X Y: a dark round button with the letter in its colour
    public static void Face(Graphics g, RectangleF r, string letter, Color colour) {
        float s = Math.Min(r.Width, r.Height), rim = s * 0.05f;
        var c = new RectangleF(r.X + (r.Width - s) / 2 + rim, r.Y + (r.Height - s) / 2 + rim, s - rim * 2, s - rim * 2);
        using (var p = new GraphicsPath()) { p.AddEllipse(c); Body3D(g, p, c, rim); }
        Text(g, letter, c, s * 0.62f, colour);
    }

    // LB RB: a bumper, wide with a rounded top
    public static void Bumper(Graphics g, RectangleF r, string text) {
        float rim = Math.Min(r.Width, r.Height) * 0.05f;
        float h = r.Height * 0.62f;
        var b = new RectangleF(r.X + rim, r.Y + (r.Height - h) / 2, r.Width - rim * 2, h);
        using (var p = Rounded(b, h * 0.42f)) Body3D(g, p, b, rim);
        Text(g, text, b, h * 0.62f, Label);
    }

    // LT RT: a trigger, taller with a round top
    public static void Trigger(Graphics g, RectangleF r, string text) {
        float rim = Math.Min(r.Width, r.Height) * 0.05f;
        var b = new RectangleF(r.X + rim, r.Y + rim, r.Width - rim * 2, r.Height - rim * 2);
        using (var p = new GraphicsPath()) {
            float rad = b.Width * 0.5f;
            p.AddArc(b.X, b.Y, b.Width, rad * 2, 180, 180);
            p.AddLine(b.Right, b.Y + rad, b.Right, b.Bottom - b.Width * 0.18f);
            p.AddArc(b.Right - b.Width * 0.36f, b.Bottom - b.Width * 0.36f, b.Width * 0.36f, b.Width * 0.36f, 0, 90);
            p.AddArc(b.X, b.Bottom - b.Width * 0.36f, b.Width * 0.36f, b.Width * 0.36f, 90, 90);
            p.CloseFigure();
            Body3D(g, p, b, rim);
        }
        Text(g, text, new RectangleF(b.X, b.Y + b.Height * 0.12f, b.Width, b.Height * 0.88f), b.Width * 0.48f, Label);
    }

    // LS RS: a stick, a ring around a dark cap with the letters
    public static void Stick(Graphics g, RectangleF r, string text) {
        float s = Math.Min(r.Width, r.Height), rim = s * 0.05f;
        var c = new RectangleF(r.X + (r.Width - s) / 2 + rim, r.Y + (r.Height - s) / 2 + rim, s - rim * 2, s - rim * 2);
        using (var p = new GraphicsPath()) { p.AddEllipse(c); Body3D(g, p, c, rim); }
        var inner = RectangleF.Inflate(c, -s * 0.13f, -s * 0.13f);
        using (var pen = new Pen(Rim, rim * 0.8f)) g.DrawEllipse(pen, inner);
        Text(g, text, c, s * 0.40f, Label);
    }

    // the d-pad: a dark cross
    public static void Dpad(Graphics g, RectangleF r) {
        float s = Math.Min(r.Width, r.Height), rim = s * 0.05f, arm = s * 0.36f;
        float cx = r.X + r.Width / 2, cy = r.Y + r.Height / 2, h = s / 2 - rim;
        using (var p = new GraphicsPath()) {
            p.AddPolygon(new[] {
                new PointF(cx - arm / 2, cy - h), new PointF(cx + arm / 2, cy - h), new PointF(cx + arm / 2, cy - arm / 2),
                new PointF(cx + h, cy - arm / 2), new PointF(cx + h, cy + arm / 2), new PointF(cx + arm / 2, cy + arm / 2),
                new PointF(cx + arm / 2, cy + h), new PointF(cx - arm / 2, cy + h), new PointF(cx - arm / 2, cy + arm / 2),
                new PointF(cx - h, cy + arm / 2), new PointF(cx - h, cy - arm / 2), new PointF(cx - arm / 2, cy - arm / 2) });
            Body3D(g, p, r, rim);
        }
    }

    // a gold arrow pointing at angle degrees (0 right, 90 down)
    public static void Arrow(Graphics g, RectangleF r, float angle) {
        float s = Math.Min(r.Width, r.Height);
        var st = g.Save();
        g.TranslateTransform(r.X + r.Width / 2, r.Y + r.Height / 2);
        g.RotateTransform(angle);
        float L = s * 0.46f, w = s * 0.13f, head = s * 0.30f;
        using (var p = new GraphicsPath()) {
            p.AddPolygon(new[] {
                new PointF(-L, -w), new PointF(L - head, -w), new PointF(L - head, -head), new PointF(L, 0),
                new PointF(L - head, head), new PointF(L - head, w), new PointF(-L, w) });
            using (var br = new LinearGradientBrush(new PointF(0, -head), new PointF(0, head), Gold, GoldDark)) g.FillPath(br, p);
            using (var pen = new Pen(Color.FromArgb(255, 90, 50, 8), s * 0.04f)) g.DrawPath(pen, p);
        }
        g.Restore(st);
    }

    // turn around: a gold ring with an arrow head
    public static void Turn(Graphics g, RectangleF r) {
        float s = Math.Min(r.Width, r.Height);
        var c = RectangleF.Inflate(new RectangleF(r.X + (r.Width - s) / 2, r.Y + (r.Height - s) / 2, s, s), -s * 0.16f, -s * 0.16f);
        using (var pen = new Pen(Gold, s * 0.13f)) { pen.StartCap = LineCap.Round; g.DrawArc(pen, c, 120, 290); }
        float a = (float)(120 * Math.PI / 180), rad = c.Width / 2;
        float ex = c.X + rad + rad * (float)Math.Cos(a), ey = c.Y + rad + rad * (float)Math.Sin(a);
        float hs = s * 0.2f;
        using (var p = new GraphicsPath()) {
            p.AddPolygon(new[] { new PointF(ex - hs, ey - hs * 0.2f), new PointF(ex + hs * 0.9f, ey - hs * 0.4f), new PointF(ex + hs * 0.1f, ey + hs) });
            using (var br = new SolidBrush(Gold)) g.FillPath(br, p);
        }
    }
}
"@

New-Item -ItemType Directory -Force $Out | Out-Null
Get-ChildItem $Out -Filter *.png | Remove-Item
$k = 4
$colours = @{ "A" = [System.Drawing.Color]::FromArgb(255, 110, 205, 70); "B" = [System.Drawing.Color]::FromArgb(255, 235, 72, 62);
              "X" = [System.Drawing.Color]::FromArgb(255, 72, 146, 240); "Y" = [System.Drawing.Color]::FromArgb(255, 245, 205, 50) }
# <atlas key> <atlas size> <button> <x> <y> <w> <h>, in the game's texels
$gems = @(
    "9bb686564c6f0e2c 512x512 A 446 278 18 23",
    "9bb686564c6f0e2c 512x512 A 472 278 18 23",
    "9bb686564c6f0e2c 512x512 B 446 210 18 23",
    "9bb686564c6f0e2c 512x512 B 446 244 18 23",
    "9bb686564c6f0e2c 512x512 X 446 108 18 23",
    "9bb686564c6f0e2c 512x512 X 446 40 18 23",
    "9bb686564c6f0e2c 512x512 Y 367 457 18 23",
    "9bb686564c6f0e2c 512x512 Y 446 346 18 23",
    "b17b1f7c7bdae1f0 512x128 A 309 74 18 23",
    "b17b1f7c7bdae1f0 512x128 A 375 6 18 23",
    "b17b1f7c7bdae1f0 512x128 B 283 74 18 23",
    "b17b1f7c7bdae1f0 512x128 B 349 6 18 23",
    "b17b1f7c7bdae1f0 512x128 X 164 90 18 23",
    "b17b1f7c7bdae1f0 512x128 X 205 59 18 23",
    "b17b1f7c7bdae1f0 512x128 Y 361 40 18 23",
    "b17b1f7c7bdae1f0 512x128 Y 387 40 18 23",
    "de07cd17538dd95b 512x512 A 157 475 18 23",
    "de07cd17538dd95b 512x512 A 205 447 18 23",
    "de07cd17538dd95b 512x512 B 313 291 18 23",
    "de07cd17538dd95b 512x512 B 339 257 18 23",
    "de07cd17538dd95b 512x512 X 257 413 18 23",
    "de07cd17538dd95b 512x512 X 488 173 18 23",
    "de07cd17538dd95b 512x512 Y 231 413 18 23",
    "de07cd17538dd95b 512x512 Y 287 291 18 23",
    "f21ef600f853b196 512x128 A 134 81 18 23",
    "f21ef600f853b196 512x128 A 160 60 18 23",
    "f21ef600f853b196 512x128 B 157 26 18 23",
    "f21ef600f853b196 512x128 B 82 94 18 23",
    "f21ef600f853b196 512x128 X 262 40 18 23",
    "f21ef600f853b196 512x128 X 288 6 18 23",
    "f21ef600f853b196 512x128 Y 212 74 18 23",
    "f21ef600f853b196 512x128 Y 236 6 18 23",
    "fa4e4282afbc6613 512x256 A 101 224 18 23",
    "fa4e4282afbc6613 512x256 A 127 224 18 23",
    "fa4e4282afbc6613 512x256 B 410 126 18 23",
    "fa4e4282afbc6613 512x256 B 490 40 18 23",
    "fa4e4282afbc6613 512x256 X 205 224 18 23",
    "fa4e4282afbc6613 512x256 X 232 190 18 23",
    "fa4e4282afbc6613 512x256 Y 180 190 18 23",
    "fa4e4282afbc6613 512x256 Y 490 6 18 23"
)
$erase = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(1, 0, 0, 0))
foreach ($atlas in ($gems | Group-Object { $_.Split(' ')[0] })) {
    $size = $atlas.Group[0].Split(' ')[1].Split('x')
    $b = New-Object System.Drawing.Bitmap ([int]$size[0] * $k), ([int]$size[1] * $k)
    $g = [Icons]::Begin($b)
    foreach ($line in $atlas.Group) {
        $f = $line.Split(' ')
        $x = [int]$f[3]; $y = [int]$f[4]; $w = [int]$f[5]; $h = [int]$f[6]
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy  # alpha 1 as it is, not blended
        $g.FillRectangle($erase, ($x - 1) * $k, ($y - 1) * $k, ($w + 2) * $k, ($h + 2) * $k)
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        # the round button as wide as the erased box, in the middle of it
        $r = New-Object System.Drawing.RectangleF (($x - 1) * $k), (($y + ($h - $w) / 2 - 1) * $k), (($w + 2) * $k), (($w + 2) * $k)
        [Icons]::Face($g, $r, $f[2], $colours[$f[2]])
    }
    $b.Save((Join-Path $Out ("{0}x{1}_{2}_overlay.png" -f $size[0], $size[1], $atlas.Name)), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $b.Dispose()
}
Get-ChildItem $Out | ForEach-Object { "{0} ({1} KB)" -f $_.Name, [int]($_.Length / 1024) }
