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

import asyncio
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

#: Standard Web Mercator slippy-tile size, same as every OSM-derived service.
_MML_TILE_PX = 256
_MML_MAX_ZOOM = 18

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


async def fetch_radar_overlay(clat: float, clon: float, radius_km: float, size: int,
                              frame: datetime) -> bytes:
    """The radar layer alone, transparent where there is no echo.

    Companion to :func:`fetch_mml_basemap` for the car screen: MML has no
    radar data of its own, so the two are fetched separately and composited
    in :func:`compose_mml` rather than asking GeoServer for both layers in
    one `GetMap` the way :func:`fetch_base` does for the bike app. Confirmed
    live (2026-10-26) that `suomi_dbz_eureffin` alone, with `transparent=true`
    and no basemap layer in the same request, returns real alpha — 0 where
    there is no echo, ~204/255 where there is — not an opaque white fill.
    """
    south, west, north, east = bbox(clat, clon, radius_km)
    response = await client().get(
        config.FMI_RADAR_WMS,
        params={
            "service": "WMS", "version": "1.3.0", "request": "GetMap",
            "layers": "Radar:suomi_dbz_eureffin",
            "styles": "", "crs": "EPSG:4326",
            "bbox": f"{south:.5f},{west:.5f},{north:.5f},{east:.5f}",
            "width": size, "height": size, "format": "image/png",
            "transparent": "true",
            "interpolations": "bilinear",
            "time": frame.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        },
    )
    if response.status_code != 200 or response.headers.get("content-type", "").split(";")[0] != "image/png":
        raise FMIError(f"radar overlay GetMap {response.status_code}: {response.text[:120]}")
    return response.content


def _lonlat_to_tilef(lon: float, lat: float, zoom: int) -> tuple[float, float]:
    """Fractional Web Mercator tile coordinates — the standard slippy-tile
    formula shared by every OSM-derived tile service, MML's WMTS included."""
    n = 2 ** zoom
    x = (lon + 180.0) / 360.0 * n
    lat_rad = math.radians(lat)
    y = (1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n
    return x, y


def _pick_zoom(west: float, east: float, lat: float, size: int) -> int:
    """The zoom level whose metres/pixel most closely matches the requested
    bbox width spread over `size` pixels — rounds to the nearest integer
    zoom rather than always rounding up, so a radius between two zooms costs
    roughly the tile count either neighbouring zoom would (not systematically
    more).
    """
    width_km = (east - west) * _KM_PER_DEG_LON_EQ * math.cos(math.radians(lat))
    target_mpp = (width_km * 1000) / size
    base_mpp_at_z0 = 156543.03392 * math.cos(math.radians(lat))
    zoom = round(math.log2(base_mpp_at_z0 / target_mpp))
    return max(0, min(_MML_MAX_ZOOM, zoom))


async def _fetch_mml_tile(x: int, y: int, zoom: int) -> Image.Image:
    url = f"{config.MML_WMTS}/1.0.0/taustakartta/default/WGS84_Pseudo-Mercator/{zoom}/{y}/{x}.png"
    response = await client().get(url, params={"api-key": config.MML_API_KEY})
    if response.status_code != 200:
        raise FMIError(f"MML tile {zoom}/{x}/{y}: {response.status_code}")
    return Image.open(io.BytesIO(response.content)).convert("RGB")


async def fetch_mml_basemap(clat: float, clon: float, radius_km: float, size: int) -> bytes:
    """Maanmittauslaitos's (National Land Survey of Finland) background map,
    stitched from WMTS tiles and cropped to exactly `size`x`size` pixels.

    Replaces `Basemaps:naturalearthgray` for the car radar screen
    (RESEARCH.md §5.5) — FMI's WMS has that one basemap layer and it is too
    coarse for a close-up car view at any resampling; MML's tile pyramid
    stays crisp at every zoom, confirmed live 2026-10-26 against a tile over
    Espoo/Helsinki at zoom 10.

    No marker, no radar, no timestamp — those belong to the frame-specific
    overlay and are composited on top in :func:`compose_mml`. This function's
    result never changes for a given (clat, clon, radius, size), so the
    caller should cache it far longer than a radar frame
    (`config.TTL_MML_BASEMAP`) — MML's own docs ask that the open interface
    not be hit at high volume, and there is no reason to re-fetch a basemap
    that cannot have changed.
    """
    if not config.MML_API_KEY:
        raise FMIError("MML_API_KEY is not set — register one at the MML OmaTili "
                       "service (RESEARCH.md §5.5) before requesting the car basemap")
    south, west, north, east = bbox(clat, clon, radius_km)
    zoom = _pick_zoom(west, east, clat, size)

    x0f, y0f = _lonlat_to_tilef(west, north, zoom)
    x1f, y1f = _lonlat_to_tilef(east, south, zoom)
    x_min, x_max = int(x0f), int(x1f)
    y_min, y_max = int(y0f), int(y1f)

    tiles = await asyncio.gather(*[
        _fetch_mml_tile(x, y, zoom)
        for y in range(y_min, y_max + 1)
        for x in range(x_min, x_max + 1)
    ])

    canvas = Image.new("RGB", (
        (x_max - x_min + 1) * _MML_TILE_PX,
        (y_max - y_min + 1) * _MML_TILE_PX,
    ))
    i = 0
    for y in range(y_min, y_max + 1):
        for x in range(x_min, x_max + 1):
            canvas.paste(tiles[i], ((x - x_min) * _MML_TILE_PX, (y - y_min) * _MML_TILE_PX))
            i += 1

    crop = (
        (x0f - x_min) * _MML_TILE_PX, (y0f - y_min) * _MML_TILE_PX,
        (x1f - x_min) * _MML_TILE_PX, (y1f - y_min) * _MML_TILE_PX,
    )
    cropped = canvas.crop(crop).resize((size, size), Image.LANCZOS)
    buf = io.BytesIO()
    cropped.save(buf, format="PNG")
    return buf.getvalue()


def compose_mml(basemap_png: bytes, overlay_png: bytes) -> bytes:
    """Alpha-composite the radar overlay onto the MML basemap.

    Separate from :func:`draw`, which still adds the marker and timestamp —
    this only merges the two source images so the result can be fed into
    :func:`draw` exactly like :func:`fetch_base`'s single-call output is for
    the bike app, reusing its marker/timestamp/quantize logic unchanged.
    """
    base = Image.open(io.BytesIO(basemap_png)).convert("RGBA")
    overlay = Image.open(io.BytesIO(overlay_png)).convert("RGBA")
    base.alpha_composite(overlay)
    buf = io.BytesIO()
    base.convert("RGB").save(buf, format="PNG")
    return buf.getvalue()


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
