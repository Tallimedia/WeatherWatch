"""Radar tile for the Edge radar app (FIBikeWeather/RESEARCH.md §6).

One small PNG centred on the rider: FMI's Finnish radar composite over a grey
land/water basemap, a marker where the rider is, and the frame time stamped in
the corner. Cropped and drawn here rather than on the device — the one Edge
radar app found in research placed its marker with hand-tuned pixel constants,
which is exactly the part that breaks silently when the image format changes.

The image is square in **kilometres**, not degrees. A degree of longitude is
about half a degree of latitude at 62°N, so a square bounding box in degrees
would be stretched. The box is built from the radius and the local cosine.
"""

from __future__ import annotations

import io
import math
import re
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from PIL import Image, ImageDraw, ImageFont

from . import config
from .fmi import FMIError, client

_HELSINKI = ZoneInfo("Europe/Helsinki")
_KM_PER_DEG_LAT = 111.2
_KM_PER_DEG_LON_EQ = 111.32

#: Radii offered by the app (RESEARCH.md §7). Anything else is rounded to the
#: nearest so the cache key space stays three entries wide per cell.
RADII_KM = (25, 50, 100)

#: Palette size for the shipped PNG. The radar legend uses a handful of colours
#: and the basemap two greys; 32 keeps rain intensities distinguishable while
#: cutting the file to a fraction of a truecolour PNG.
PALETTE_COLOURS = 32

_FRAME_RE = re.compile(
    r"<Name>suomi_dbz_eureffin</Name>.*?<Dimension name=\"time\"[^>]*>([^<]+)</Dimension>",
    re.S,
)


def snap_radius(radius_km: float) -> int:
    return min(RADII_KM, key=lambda r: abs(r - radius_km))


def bbox(lat: float, lon: float, radius_km: float) -> tuple[float, float, float, float]:
    """(south, west, north, east) in degrees for a box ``radius_km`` each way."""
    dlat = radius_km / _KM_PER_DEG_LAT
    dlon = radius_km / (_KM_PER_DEG_LON_EQ * math.cos(math.radians(lat)))
    return lat - dlat, lon - dlon, lat + dlat, lon + dlon


def snap_centre(lat: float, lon: float) -> tuple[float, float]:
    """Snap the tile centre to a 0.05° grid (~5 km) so neighbouring requests share a tile.

    The rider's true position is drawn as an offset from this centre, so
    snapping costs nothing in accuracy — it only decides which cached base
    image is reused.
    """
    return round(lat / 0.05) * 0.05, round(lon / 0.05) * 0.05


def marker_pixel(lat: float, lon: float, clat: float, clon: float,
                 radius_km: float, size: int) -> tuple[float, float]:
    """Pixel position of the rider inside a tile centred on (clat, clon)."""
    south, west, north, east = bbox(clat, clon, radius_km)
    x = (lon - west) / (east - west) * size
    y = (north - lat) / (north - south) * size
    return x, y


def parse_latest_frame(capabilities: str) -> datetime:
    """Newest frame time of the radar composite, from the WMS capabilities.

    The layer's time dimension is ``start/end/PT5M``; the end is the newest
    frame. GetMap without a TIME returns that frame, so this is only needed to
    say *which* frame it is — the device cannot otherwise tell a fresh tile from
    a stale one.
    """
    match = _FRAME_RE.search(capabilities)
    if not match:
        raise FMIError("radar: no time dimension for suomi_dbz_eureffin")
    end = match.group(1).strip().split("/")[1]
    return datetime.fromisoformat(end.replace("Z", "+00:00"))


async def fetch_latest_frame() -> datetime:
    response = await client().get(
        config.FMI_RADAR_CAPS,
        params={"service": "WMS", "version": "1.3.0", "request": "GetCapabilities"},
    )
    if response.status_code != 200:
        raise FMIError(f"radar capabilities {response.status_code}")
    return parse_latest_frame(response.text)


async def fetch_base(clat: float, clon: float, radius_km: float, size: int,
                     frame: datetime) -> bytes:
    """The basemap-plus-radar PNG for one frame, centred on a snapped point.

    ``TIME`` is passed explicitly so the tile and the stamp drawn on it cannot
    disagree if a newer frame arrives between the two upstream calls.
    """
    south, west, north, east = bbox(clat, clon, radius_km)
    response = await client().get(
        config.FMI_RADAR_WMS,
        params={
            "service": "WMS", "version": "1.3.0", "request": "GetMap",
            "layers": "Basemaps:naturalearthgray,Radar:suomi_dbz_eureffin",
            "styles": "", "crs": "EPSG:4326",
            # WMS 1.3.0 with EPSG:4326 is latitude-first.
            "bbox": f"{south:.5f},{west:.5f},{north:.5f},{east:.5f}",
            "width": size, "height": size, "format": "image/png",
            "time": frame.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        },
    )
    if response.status_code != 200 or response.headers.get("content-type", "").split(";")[0] != "image/png":
        raise FMIError(f"radar GetMap {response.status_code}: {response.text[:120]}")
    return response.content


def draw(base_png: bytes, px: float, py: float, frame: datetime) -> bytes:
    """Add the rider marker and frame time, then reduce to a small palette PNG."""
    image = Image.open(io.BytesIO(base_png)).convert("RGB")
    d = ImageDraw.Draw(image)
    size = image.width

    # Crosshair-in-ring: visible over both the grey basemap and any rain colour.
    r = max(6, size // 40)
    for width, colour in ((4, (255, 255, 255)), (2, (0, 0, 0))):
        d.ellipse((px - r, py - r, px + r, py + r), outline=colour, width=width)
    d.line((px - r * 2, py, px + r * 2, py), fill=(0, 0, 0), width=2)
    d.line((px, py - r * 2, px, py + r * 2), fill=(0, 0, 0), width=2)

    label = frame.astimezone(_HELSINKI).strftime("%H:%M")
    font = ImageFont.load_default(size=max(14, size // 16))
    box = d.textbbox((0, 0), label, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    pad = 4
    d.rectangle((0, size - th - pad * 3, tw + pad * 3, size), fill=(255, 255, 255))
    d.text((pad, size - th - pad * 2 - box[1]), label, fill=(0, 0, 0), font=font)

    out = io.BytesIO()
    image.quantize(PALETTE_COLOURS, method=Image.Quantize.MEDIANCUT).save(
        out, format="PNG", optimize=True
    )
    return out.getvalue()
