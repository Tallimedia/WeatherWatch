#!/usr/bin/env python3
"""Render the Connect IQ Store artwork.

  hero-1440x720.png    banner
  cover-500x500.png    square tile

Same visual family as VolvoWatch's store art — dark navy, text left, device
right — so the two listings read as siblings from the same maker.

The watch screen is **a real capture**, pasted into the SDK's own device skin,
not a redrawing of it. Artwork that re-implements the screen drifts from the
product the first time the product changes; this cannot.

    python3 watch/store/make_store_art.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
HERO = HERE / "hero-1440x720.png"
COVER = HERE / "cover-500x500.png"

# The Land page, straight from the simulator at the shipped build.
CAPTURE = Path(__file__).resolve().parents[2] / "Screenshots" / "pg1.png"

# Palette — VolvoWatch's, deliberately. Two apps from one shelf.
BG_TOP = (9, 13, 26)
BG_BOTTOM = (19, 26, 48)
WHITE = (245, 248, 253)
GREY = (150, 166, 194)
DIM = (98, 112, 138)
ACCENT = (94, 148, 255)

# The real fenix847mm skin the simulator renders — read from the installed SDK
# rather than copied into the repo, since it is not ours to redistribute.
DEVICE_SKIN_PATH = (
    Path.home() / "Library/Application Support/Garmin/ConnectIQ/Devices"
    / "fenix847mm" / "fenix847mm.png"
)
SCREEN_RECT = (134, 221, 454, 454)  # x, y, w, h — from that device's simulator.json

SF = "/System/Library/Fonts/SFNS.ttf"
HELV = "/System/Library/Fonts/HelveticaNeue.ttc"


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    """SF with a variation axis where possible, Helvetica Neue otherwise."""
    try:
        f = ImageFont.truetype(SF, size)
        try:
            f.set_variation_by_name("Bold" if weight == "bold" else "Regular")
        except Exception:
            pass
        return f
    except Exception:
        return ImageFont.truetype(HELV, size)


def vertical_gradient(size: tuple[int, int], top, bottom) -> Image.Image:
    w, h = size
    grad = Image.new("RGB", (1, h))
    px = grad.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        px[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return grad.resize((w, h))


def centered(draw, cx, cy, text, fnt, fill):
    l, t, r, b = draw.textbbox((0, 0), text, font=fnt)
    draw.text((cx - (r + l) / 2, cy - (b + t) / 2), text, font=fnt, fill=fill)


_cutout: Image.Image | None = None


def skin_cutout() -> Image.Image:
    """Device skin with its white background stripped, so the case composites
    onto our own gradient instead of arriving in a white box."""
    global _cutout
    if _cutout is not None:
        return _cutout
    if not DEVICE_SKIN_PATH.exists():
        raise SystemExit(
            f"device skin not found at {DEVICE_SKIN_PATH}\n"
            "Install the fenix847mm device in the Connect IQ SDK Manager."
        )
    arr = np.array(Image.open(DEVICE_SKIN_PATH).convert("RGBA"))
    near_white = (arr[:, :, :3] >= 250).all(axis=2) & (arr[:, :, 3] == 255)
    arr[near_white, 3] = 0
    _cutout = Image.fromarray(arr)
    return _cutout


def device(height: int) -> Image.Image:
    """The watch, screen filled with the real capture, scaled to `height`."""
    if not CAPTURE.exists():
        raise SystemExit(f"no capture at {CAPTURE} — take one from the simulator first")
    skin = skin_cutout().copy()
    shot = Image.open(CAPTURE).convert("RGBA")

    x, y, w, h = SCREEN_RECT
    if shot.size != (w, h):
        shot = shot.resize((w, h), Image.LANCZOS)

    # Round the capture: the screen is circular and the corners of a square
    # paste would sit proud of the bezel.
    mask = Image.new("L", (w * 4, h * 4), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, w * 4 - 1, h * 4 - 1], fill=255)
    shot.putalpha(mask.resize((w, h), Image.LANCZOS))

    screen = Image.new("RGBA", skin.size, (0, 0, 0, 0))
    screen.paste(shot, (x, y), shot)
    # Under the skin, so the case edge overlaps the capture rather than the
    # other way round.
    out = Image.alpha_composite(screen, skin)

    scale = height / out.size[1]
    return out.resize((round(out.size[0] * scale), height), Image.LANCZOS)


def glow(img: Image.Image, cx: int, cy: int, radius: int, steps: int = 60) -> Image.Image:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(steps, 0, -1):
        r = radius + i * 4
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(40, 74, 150, 3))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def make_hero() -> None:
    W, H = 1440, 720
    img = glow(vertical_gradient((W, H), BG_TOP, BG_BOTTOM), 1080, 360, 250)

    watch = device(620)
    img.paste(watch, (1080 - watch.size[0] // 2, 360 - watch.size[1] // 2), watch)

    d = ImageDraw.Draw(img)
    x, max_w = 96, 660

    title = "FIWeatherWatch"
    size = 74
    while size > 34 and d.textlength(title, font=font(size, "bold")) > max_w:
        size -= 2
    d.text((x, 186), title, font=font(size, "bold"), fill=WHITE)

    d.text((x, 286), "Finnish weather, land and sea —", font=font(31), fill=GREY)
    d.text((x, 328), "straight from the source.", font=font(31), fill=GREY)

    bullets = [
        "Forecasts and live observations",
        "Marine wind and gusts from 22 coastal stations",
        "Wave height and water temperature from FMI buoys",
        "Your own wind, gust and wave limits",
    ]
    by = 410
    for line in bullets:
        d.ellipse([x + 4, by + 12, x + 14, by + 22], fill=ACCENT)
        d.text((x + 32, by), line, font=font(25), fill=WHITE)
        by += 44

    d.text((x, 616), "Weather data: Finnish Meteorological Institute, CC BY 4.0.",
           font=font(19), fill=DIM)
    d.text((x, 646), "Independent project — not affiliated with FMI or Garmin.",
           font=font(19), fill=DIM)

    img.save(HERO, "PNG")
    print(f"{HERO.name}  {img.size[0]}x{img.size[1]}  {HERO.stat().st_size:,} bytes")


def make_cover() -> None:
    """500x500 tile. Read at thumbnail size, so: fewer words, bigger device."""
    S = 500
    img = glow(vertical_gradient((S, S), BG_TOP, BG_BOTTOM), S // 2, 228, 150, steps=50)

    watch = device(404)
    img.paste(watch, (S // 2 - watch.size[0] // 2, 228 - watch.size[1] // 2), watch)

    d = ImageDraw.Draw(img)
    centered(d, S // 2, 462, "FIWeatherWatch", font(30, "bold"), WHITE)

    img.save(COVER, "PNG")
    print(f"{COVER.name}  {img.size[0]}x{img.size[1]}  {COVER.stat().st_size:,} bytes")


if __name__ == "__main__":
    make_hero()
    make_cover()
