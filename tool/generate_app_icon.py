#!/usr/bin/env python3
"""
Generate the UniVerse launcher icon from the splash-screen "orbit" mark.

Reproduces lib/features/auth/screens/splash_screen.dart `_OrbitPainter`
(planet + elliptical orbit ring + orbiting dot) at high resolution using the
brand tokens from lib/core/theme/app_colors.dart, and writes:

  assets/icon/app_icon.png             legacy square icon (opaque dark bg)
  assets/icon/app_icon_foreground.png  adaptive foreground (transparent, inset)

Then `dart run flutter_launcher_icons` turns these into the Android mipmaps.
Re-run after tweaking the mark:  python tool/generate_app_icon.py
"""

import os
from PIL import Image, ImageDraw, ImageFilter

# ─── Brand tokens (app_colors.dart) ─────────────────────────
PRIMARY = (0xFF, 0x7A, 0x00, 255)   # AppColors.primary
BG      = (0x0F, 0x0F, 0x10, 255)   # AppColors.bgPrimary
BG_CTR  = (0x1C, 0x1A, 0x1A, 255)   # subtle warm lift at the centre

SS = 4                              # supersampling factor
OUT = 1024                          # final icon size
N = OUT * SS                        # working canvas size

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(HERE, "assets", "icon")


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def radial_bg(size, center_col, edge_col):
    """Smooth radial: render small, upscale (cheap + smooth)."""
    small = 96
    s = Image.new("RGBA", (small, small))
    px = s.load()
    for y in range(small):
        for x in range(small):
            dx = (x + 0.5) / small - 0.5
            dy = (y + 0.5) / small - 0.5
            d = min(1.0, ((dx * dx + dy * dy) ** 0.5) / 0.62)
            px[x, y] = lerp(center_col, edge_col, d)
    return s.resize((size, size), Image.BILINEAR)


def draw_mark(base, cx, cy, m):
    """Draw the orbit mark centred at (cx, cy) with scale m (the painter 'size')."""
    planet_r = 0.180 * m
    ring_w = 0.90 * m
    ring_h = 0.45 * m
    ring_sw = max(2, int(0.045 * m))
    dot_r = 0.080 * m
    dot_x = cx + 0.42 * m
    dot_y = cy

    # Soft glow behind the planet + dot for depth.
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gp = planet_r * 2.3
    gd.ellipse([cx - gp, cy - gp, cx + gp, cy + gp], fill=(255, 122, 0, 95))
    gq = dot_r * 2.6
    gd.ellipse([dot_x - gq, dot_y - gq, dot_x + gq, dot_y + gq],
               fill=(255, 122, 0, 75))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=int(0.11 * m)))
    base.alpha_composite(glow)

    d = ImageDraw.Draw(base)
    # Orbit ring (~55% alpha, like the splash).
    d.ellipse([cx - ring_w / 2, cy - ring_h / 2, cx + ring_w / 2, cy + ring_h / 2],
              outline=(255, 122, 0, 140), width=ring_sw)
    # Planet.
    d.ellipse([cx - planet_r, cy - planet_r, cx + planet_r, cy + planet_r],
              fill=PRIMARY)
    # Orbiting dot (sits on the ring's right side).
    d.ellipse([dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r],
              fill=PRIMARY)


def build_legacy():
    img = radial_bg(N, BG_CTR, BG)
    m = 0.52 * N
    # Shift left to balance the orbiting dot, so the mark reads centred.
    draw_mark(img, N / 2 - 0.025 * m, N / 2, m)
    img = img.resize((OUT, OUT), Image.LANCZOS)
    img.save(os.path.join(ICON_DIR, "app_icon.png"))


def build_foreground():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    m = 0.60 * N  # kept inside the adaptive safe zone (~66%)
    draw_mark(img, N / 2 - 0.025 * m, N / 2, m)
    img = img.resize((OUT, OUT), Image.LANCZOS)
    img.save(os.path.join(ICON_DIR, "app_icon_foreground.png"))


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    build_legacy()
    build_foreground()
    print("Wrote:")
    print("  assets/icon/app_icon.png")
    print("  assets/icon/app_icon_foreground.png")


if __name__ == "__main__":
    main()
