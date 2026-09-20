#!/usr/bin/env python3
"""Composite raw simulator captures into the real watch.

A bare capture is a flat 454x454 square, which reads as a screenshot of
nothing in particular. Dropping it into the device skin makes it read as a
photo of the watch — the same treatment VolvoWatch uses for its store art
(`VolvoWatch/watch/store/make_store_art.py`).

The skin and its screen rectangle come from the installed SDK rather than being
copied here: it is Garmin's artwork, and reading it in place means the geometry
can never drift from the device the app is actually built for.

    python3 Screenshots/frame.py            # every *.png next to this file
    python3 Screenshots/frame.py pg1.png    # just one
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).parent
OUT = HERE / "framed"
DEVICE = "fenix847mm"
SDK_DEVICES = Path.home() / "Library/Application Support/Garmin/ConnectIQ/Devices"

# Raw captures go in; framed ones come out. Anything already framed is skipped
# so a second run does not nest a watch inside a watch.
SKIP = {"framed"}


def geometry() -> tuple[Image.Image, tuple[int, int, int, int]]:
    skin_path = SDK_DEVICES / DEVICE / f"{DEVICE}.png"
    sim_path = SDK_DEVICES / DEVICE / "simulator.json"
    if not skin_path.exists() or not sim_path.exists():
        raise SystemExit(f"SDK device files not found for {DEVICE} — is the SDK installed?")
    loc = json.loads(sim_path.read_text())["display"]["location"]
    return Image.open(skin_path).convert("RGBA"), (
        loc["x"], loc["y"], loc["width"], loc["height"],
    )


def frame(src: Path, skin: Image.Image, rect: tuple[int, int, int, int]) -> Path:
    shot = Image.open(src).convert("RGBA")
    x, y, w, h = rect
    canvas = skin.copy()
    disc = shot.resize((w, h), Image.LANCZOS)
    # Circular mask: the capture is square but the display is round, and the
    # corners would otherwise paint over the bezel.
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, w - 1, h - 1], fill=255)
    canvas.paste(disc, (x, y), mask)
    OUT.mkdir(exist_ok=True)
    out = OUT / src.name
    canvas.save(out)
    return out


def main() -> None:
    skin, rect = geometry()
    names = sys.argv[1:]
    if names:
        sources = [HERE / n for n in names]
    else:
        sources = sorted(p for p in HERE.glob("*.png") if p.parent.name not in SKIP)
    if not sources:
        raise SystemExit("no captures found")
    for src in sources:
        out = frame(src, skin, rect)
        print(f"{src.name:14} -> {out.relative_to(HERE)}  {out.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
