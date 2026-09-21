#!/usr/bin/env python3
"""Crop phone screenshots of the Garmin Connect settings for the website.

Two things go: the iOS status bar at the top — clock, signal, battery, none of
which is about this app — and the dead black below the last setting, which on a
tall phone is most of the image and would make every thumbnail mostly empty.

Garmin's own "Settings" bar is kept: it identifies what the reader is looking
at, and the section heading alone does not.

    python3 Screenshots/crop_settings.py <src-dir>
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "app" / "public" / "shots"

# Source file -> published name. Order is the order they appear on the page.
MAPPING = {
    "17.png": "settings-main.png",     # the Settings menu
    "16.png": "settings-land.png",     # place, wind limit, cold, hot
    "15.png": "settings-sea.png",      # station, buoy, wind and wave limits
    "14.png": "settings-display.png",  # page order, glance slots
    "13.png": "settings-units.png",    # wind, distance
}

STATUS_BAR_PX = 145   # measured: clock band ends at 100, gap to 145
PAD_BOTTOM = 28


def content_bottom(im: Image.Image) -> int:
    """Last row that still has settings content on it."""
    px = im.convert("RGB").load()
    w, h = im.size
    for y in range(h - 1, STATUS_BAR_PX, -1):
        row = [sum(px[x, y]) / 3 for x in range(10, w - 10, 25)]
        if sum(row) / len(row) > 20:          # content sits around 29, black is 0
            return y
    return h - 1


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    OUT.mkdir(parents=True, exist_ok=True)
    for source, name in MAPPING.items():
        path = src / source
        if not path.exists():
            print(f"  {source:10} missing — skipped")
            continue
        im = Image.open(path)
        bottom = min(im.size[1], content_bottom(im) + PAD_BOTTOM)
        out = im.crop((0, STATUS_BAR_PX, im.size[0], bottom))
        out.save(OUT / name, "PNG", optimize=True)
        kb = (OUT / name).stat().st_size / 1024
        print(f"  {source:10} -> {name:24} {out.size[0]}x{out.size[1]}  {kb:,.0f} kB")


if __name__ == "__main__":
    main()
