#!/usr/bin/env python3
"""Draws the Sottodesu app icon and writes the macOS AppIcon set.

    python3 Tools/make_icon.py        (needs Pillow: pip install pillow)

The design: a sheet of washi paper, a vermilion sun, and three sumi-ink bars
sorted from long to short. Everything sits on a 1024 grid; the paper plate
follows Apple's macOS icon template (824 px, centred).
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "Sottodesu/Assets.xcassets/AppIcon.appiconset"
SS = 4  # supersampling factor for smooth edges
CANVAS = 1024

PAPER = (245, 240, 228, 255)      # washi
EDGE = (224, 217, 201, 255)
INK = (34, 32, 30, 255)           # sumi
VERMILION = (216, 67, 31, 255)    # shu


def s(v):
    return v * SS


def superellipse(cx, cy, r, n=5.0, steps=1440):
    """Apple-style rounded square (a squircle)."""
    points = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, sn = math.cos(t), math.sin(t)
        x = cx + r * math.copysign(abs(c) ** (2 / n), c)
        y = cy + r * math.copysign(abs(sn) ** (2 / n), sn)
        points.append((s(x), s(y)))
    return points


def draw_master():
    size = s(CANVAS)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # soft shadow under the plate
    shadow = Image.new("L", (size, size), 0)
    ImageDraw.Draw(shadow).polygon(superellipse(512, 526, 412), fill=70)
    shadow = shadow.filter(ImageFilter.GaussianBlur(s(16)))
    img.paste((0, 0, 0, 255), mask=shadow)

    d = ImageDraw.Draw(img)
    d.polygon(superellipse(512, 512, 412), fill=PAPER, outline=EDGE, width=s(2))

    # the sun
    cx, cy, r = 644, 372, 118
    d.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=VERMILION)

    # three bars, long to short, left-aligned; the longest ends under the sun's right edge
    for y, length in [(548, 500), (644, 380), (740, 260)]:
        d.rounded_rectangle([s(262), s(y), s(262 + length), s(y + 40)], radius=s(20), fill=INK)

    return img.resize((CANVAS, CANVAS), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    master = draw_master()
    for px in (16, 32, 64, 128, 256, 512, 1024):
        icon = master if px == CANVAS else master.resize((px, px), Image.LANCZOS)
        icon.save(OUT / f"icon_{px}.png")

    images = []
    for points, scale in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                          (256, 1), (256, 2), (512, 1), (512, 2)]:
        images.append({
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{points}x{points}",
            "filename": f"icon_{points * scale}.png",
        })
    (OUT / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print(f"Wrote {len(images)} entries to {OUT}")


if __name__ == "__main__":
    main()
