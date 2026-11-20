#!/usr/bin/env python3
"""MiliConfig's neon shield mark, drawn for every launcher, splash and status-bar size.

The design is the app's brand: a glowing green shield outline around a rounded M whose
two uprights end in dots. Everything is drawn at 4x and downsampled, so the PNGs stay
crisp at every density. Run from the repository root:

    python3 scripts/make_brand_assets.py

Needs Pillow (``pip install pillow``). The SVG sources in images/icon/ mirror it.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
GREEN = (57, 255, 90)
GREEN_HI = (140, 255, 125)
GREEN_DEEP = (9, 96, 38)
BG = (4, 8, 6)
SS = 4  # supersampling


def shield_path(w: float, h: float, inset: float = 0.0) -> list[tuple[float, float]]:
    """The outline's points, clockwise from the top centre."""
    x0, y0 = inset, inset
    x1, y1 = w - inset, h - inset
    cx = (x0 + x1) / 2
    top = y0 + (y1 - y0) * 0.10
    shoulder = y0 + (y1 - y0) * 0.18
    side_top = y0 + (y1 - y0) * 0.26
    side_bottom = y0 + (y1 - y0) * 0.62
    bottom = y1 - (y1 - y0) * 0.06
    # Top centre, then down each side with rounded shoulders, then the bottom point.
    return [
        (cx, top),
        (x1 - (x1 - x0) * 0.13, shoulder),
        (x1 - (x1 - x0) * 0.10, side_top),
        (x1 - (x1 - x0) * 0.10, side_bottom),
        (cx, bottom),
        (x0 + (x1 - x0) * 0.10, side_bottom),
        (x0 + (x1 - x0) * 0.10, side_top),
        (x0 + (x1 - x0) * 0.13, shoulder),
    ]


def draw_mark(
    draw: ImageDraw.ImageDraw,
    w: float,
    h: float,
    *,
    color: tuple[int, int, int],
    alpha: int = 255,
    shield_width: float = 0.052,
    m_width: float = 0.072,
    dots: bool = True,
) -> None:
    """The shield outline and M, in a box of w x h at the origin."""
    sw = max(1, int(w * shield_width))
    outline = shield_path(w, h, inset=w * 0.075)
    draw.line(outline + [outline[0]], fill=(*color, alpha), width=sw, joint="curve")
    for p in (outline[0],):
        r = sw / 2
        draw.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=(*color, alpha))

    # The M: two uprights from the baseline to the shoulders, joined by a V into the centre.
    left = w * 0.345
    right = w * 0.655
    bar_top = h * 0.445
    bar_bottom = h * 0.705
    mid = h * 0.615
    mw = max(1, int(w * m_width))
    draw.line([(left, bar_bottom), (left, bar_top), (w / 2, mid), (right, bar_top), (right, bar_bottom)],
              fill=(*color, alpha), width=mw, joint="curve")
    if dots:
        r = mw * 0.78
        for x, y in ((left, bar_top), (right, bar_top), (w / 2, mid)):
            draw.ellipse((x - r, y - r, x + r, y + r), fill=(*color, alpha))


def glow_layer(w: int, h: int, color=GREEN, scale: float = 1.0) -> Image.Image:
    layer = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    draw_mark(
        d,
        w * SS,
        h * SS,
        color=color,
        alpha=180,
        shield_width=0.06 * scale,
        m_width=0.082 * scale,
    )
    layer = layer.filter(ImageFilter.GaussianBlur(w * SS * 0.035))
    return layer.resize((w, h), Image.LANCZOS)


def mark_image(w: int, h: int, *, white: bool = False) -> Image.Image:
    """Transparent canvas with the neon mark (or a white silhouette)."""
    big = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    if not white:
        # Bloom behind the crisp strokes.
        for spread, alpha in ((0.075, 38), (0.045, 70), (0.022, 110)):
            glow = Image.new("RGBA", big.size, (0, 0, 0, 0))
            gd = ImageDraw.Draw(glow)
            draw_mark(
                gd,
                w * SS,
                h * SS,
                color=GREEN,
                alpha=alpha,
                shield_width=0.052 + spread,
                m_width=0.072 + spread,
            )
            glow = glow.filter(ImageFilter.GaussianBlur(w * SS * 0.03))
            big = Image.alpha_composite(big, glow)
    d = ImageDraw.Draw(big)
    draw_mark(
        d,
        w * SS,
        h * SS,
        color=(255, 255, 255) if white else GREEN_HI,
        shield_width=0.052,
        m_width=0.072,
    )
    return big.resize((w, h), Image.LANCZOS)


def background(size: int, round_icon: bool = False) -> Image.Image:
    big = Image.new("RGBA", (size * SS, size * SS), (*BG, 255))
    px = big.load()
    c = size * SS / 2
    max_r = size * SS * 0.62
    for y in range(size * SS):
        for x in range(size * SS):
            dist = math.hypot(x - c, y - c)
            # Deep green halo in the middle, fading to near-black at the edges.
            t = max(0.0, 1.0 - dist / max_r)
            g = int(6 + 26 * t * t)
            r = int(BG[0] + 4 * t * t)
            b = int(BG[2] + 12 * t * t)
            px[x, y] = (r, g, b, 255)
    if round_icon:
        mask = Image.new("L", big.size, 0)
        ImageDraw.Draw(mask).ellipse((0, 0, big.size[0], big.size[1]), fill=255)
        out = Image.new("RGBA", big.size, (0, 0, 0, 0))
        out.paste(big, (0, 0), mask)
        big = out
    return big.resize((size, size), Image.LANCZOS)


def legacy_icon(size: int, round_icon: bool = False) -> Image.Image:
    base = background(size, round_icon=round_icon)
    inset = int(size * 0.17)
    mark = mark_image(size - 2 * inset, size - 2 * inset)
    base.alpha_composite(mark, (inset, inset))
    return base


def adaptive_foreground(size: int) -> Image.Image:
    # Adaptive icons are 108dp; the safe zone is the central 66dp.
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark_size = int(size * 0.62)
    mark = mark_image(mark_size, mark_size)
    canvas.alpha_composite(mark, ((size - mark_size) // 2, (size - mark_size) // 2))
    return canvas


def adaptive_background(size: int) -> Image.Image:
    base = background(size)
    return base


def notification_icon(size: int) -> Image.Image:
    # Status-bar icons are alpha-only: a white silhouette on transparent.
    canvas = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    draw_mark(
        ImageDraw.Draw(canvas),
        size * SS,
        size * SS,
        color=(255, 255, 255),
        shield_width=0.075,
        m_width=0.10,
    )
    return canvas.resize((size, size), Image.LANCZOS)


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(f"  {path.relative_to(ROOT)}  {image.size[0]}x{image.size[1]}")


def main() -> None:
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    densities = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}

    print("Launcher icons")
    for density, scale in densities.items():
        folder = res / f"mipmap-{density}"
        save(legacy_icon(int(48 * scale)), folder / "ic_launcher.png")
        save(legacy_icon(int(48 * scale), round_icon=True), folder / "ic_launcher_round.png")
        save(adaptive_foreground(int(108 * scale)), folder / "ic_launcher_foreground.png")
        save(adaptive_background(int(108 * scale)), folder / "ic_launcher_background.png")
        mono = adaptive_foreground(int(108 * scale)).convert("RGBA")
        mono_white = Image.new("RGBA", mono.size, (0, 0, 0, 0))
        # Keep the mark's alpha, paint it white.
        white = Image.new("RGBA", mono.size, (255, 255, 255, 0))
        white.putalpha(mono.getchannel("A"))
        mono_white.alpha_composite(white)
        save(mono_white, folder / "ic_launcher_monochrome.png")
        save(mark_image(int(160 * scale), int(160 * scale)), res / f"drawable-{density}" / "splash_icon.png")
        save(notification_icon(int(24 * scale)), res / f"drawable-{density}" / "ic_stat_vpn.png")

    print("In-app title icon")
    for folder, size in (("", 24), ("1.5x", 36), ("2.0x", 48), ("3.0x", 72), ("4.0x", 96)):
        path = ROOT / "assets" / "icons" / folder
        save(notification_icon(size), path / "ic_stat_vpn.png")

    print("Brand source preview")
    save(legacy_icon(512, round_icon=True), ROOT / "images" / "icon" / "preview.png")


if __name__ == "__main__":
    main()
