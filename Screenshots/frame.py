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

# The Connect IQ store rejects screenshots over 300 kB. A framed capture is
# around that as plain RGB, so it is palettised only if it has to be.
STORE_MAX_BYTES = 300_000
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


def save_under_cap(img: Image.Image, out: Path, cap: int = STORE_MAX_BYTES) -> None:
    """Save a PNG under `cap` bytes, palettising only as far as it has to.

    FASTOCTREE, not MEDIANCUT. MEDIANCUT picks palette entries by splitting the
    colour *population*, so a small saturated region loses to a large neutral
    one and gets merged into it. That matters here specifically: a threshold
    breach is a handful of blue or orange pixels against a large grey device
    photo, and those are the pixels the screenshot exists to show. FASTOCTREE
    partitions the colour *space* instead, so a distinct hue keeps its own
    entry however few pixels carry it.

    (Same conclusion VolvoWatch reached for its green charging text —
    `VolvoWatch/watch/store/make_store_art.py`.)
    """
    rgb = img.convert("RGB")
    rgb.save(out, "PNG", optimize=True)
    if out.stat().st_size <= cap:
        return
    for colours in (256, 192, 128, 96, 64):
        rgb.quantize(
            colors=colours, method=Image.FASTOCTREE, dither=Image.Dither.NONE
        ).save(out, "PNG", optimize=True)
        if out.stat().st_size <= cap:
            return


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
    save_under_cap(canvas, out)
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
        size = out.stat().st_size
        flag = "" if size <= STORE_MAX_BYTES else "  OVER STORE LIMIT"
        print(f"{src.name:14} -> {out.relative_to(HERE)}  {size:>7,} B{flag}")


if __name__ == "__main__":
    main()
