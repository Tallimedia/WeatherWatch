"""Radar tile, shared by the Edge radar app (FIBikeWeather/RESEARCH.md §6) and
the car's rain radar screen (FIRoadWeather/RESEARCH.md §5.5).

One PNG centred on the rider or car: FMI's Finnish radar composite over a grey
land/water basemap, a marker where they are, and the frame time stamped in the
corner. Cropped and drawn here rather than on the device — the one Edge radar
app found in research placed its marker with hand-tuned pixel constants, which
is exactly the part that breaks silently when the image format changes.

National reflectivity (`suomi_dbz_eureffin`) is the layer for both apps — not
HydroClass, which exists only per-radar-site with no national mosaic and would
leave most of a long drive blank (RESEARCH.md §5.5). The two callers differ
only in tile size and byte budget: see MAX_TILE_BYTES vs CAR_MAX_TILE_BYTES.

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

#: The Edge's phone link fails ("error 0") on a large image: a 420 px tile of dense rain
#: is ~48 kB, while the 15-20 kB tiles of a quiet day always arrived. FMI's composite is
#: a ~1 km grid, so the picture is shrunk to its real resolution and scaled back up in
#: blocks, using the smallest block size that keeps the file under this many bytes: sharp
#: when it is dry, blockier when the whole tile is rain. Nothing real is lost.
MAX_TILE_BYTES = 20_000
BLOCK_STEPS = (1, 2, 3, 4, 5, 6)

#: The car screen's budget (FIRoadWeather, /v1/road/radar). Fetched over the
#: car's own data connection, not relayed through a phone link, so there is
#: no transfer-size failure mode to protect against — only ordinary page
#: weight. 10x the Edge's budget still downloads well under a second on
#: anything but a dead cell signal, and avoids the heavy blockiness
#: MAX_TILE_BYTES forces on a busy radar frame.
CAR_MAX_TILE_BYTES = 200_000

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
            # GeoServer defaults to nearest-neighbour, which visibly blocks
            # up both the coastline and the radar echoes at these pixel
            # sizes — the source grid is coarser than the requested image.
            # One value per layer (confirmed live against openwms.fmi.fi,
            # 2026-10-24): same bbox/size, 40 kB nearest vs 82 kB bilinear,
            # and the bilinear tile is the one that doesn't look broken on a
            # full-screen car display (FIRoadWeather/RESEARCH.md §5.5).
            "interpolations": "bilinear,bilinear",
            "time": frame.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        },
    )
    if response.status_code != 200 or response.headers.get("content-type", "").split(";")[0] != "image/png":
        raise FMIError(f"radar GetMap {response.status_code}: {response.text[:120]}")
    return response.content


def draw(base_png: bytes, px: float, py: float, frame: datetime,
        max_bytes: int = MAX_TILE_BYTES) -> bytes:
    """Add the rider/car marker and frame time, then reduce to a small palette PNG.

    The largest block factor in BLOCK_STEPS is tried from the smallest up until the file
    fits ``max_bytes`` (see the note on MAX_TILE_BYTES); the last one is returned if none
    does. ``max_bytes`` defaults to the Edge's tight budget; the car client passes a looser
    one (FIRoadWeather/RESEARCH.md §5.5) since it has no Bluetooth/ANT+ transfer to protect.
    """
    original = Image.open(io.BytesIO(base_png)).convert("RGB")
    out = b""
    for factor in BLOCK_STEPS:
        out = _encode(original, factor, px, py, frame)
        if len(out) <= max_bytes:
            break
    return out


def _encode(original: Image.Image, factor: int, px: float, py: float, frame: datetime) -> bytes:
    image = original
    if factor > 1:
        small = original.resize(
            (max(1, original.width // factor), max(1, original.height // factor)), Image.NEAREST
        )
        image = small.resize(original.size, Image.NEAREST)
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

    buf = io.BytesIO()
    image.quantize(PALETTE_COLOURS, method=Image.Quantize.MEDIANCUT).save(
        buf, format="PNG", optimize=True
    )
    return buf.getvalue()
