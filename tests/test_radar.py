"""Radar tile geometry and drawing — the part the Edge radar precedent got wrong."""

import io
from datetime import datetime, timezone

import pytest
from PIL import Image

from app import radar
from app.fmi import FMIError
from app.geo import haversine_km


def test_box_is_square_in_kilometres_not_degrees():
    s, w, n, e = radar.bbox(62.9, 27.7, 50)
    height = haversine_km(s, 27.7, n, 27.7)
    width = haversine_km(62.9, w, 62.9, e)
    assert height == pytest.approx(100, rel=0.01)
    assert width == pytest.approx(100, rel=0.01)
    # ...which in degrees is visibly not square at this latitude.
    assert (e - w) > 1.5 * (n - s)


def test_rider_at_the_centre_is_drawn_at_the_middle():
    x, y = radar.marker_pixel(62.9, 27.7, 62.9, 27.7, 50, 360)
    assert (x, y) == pytest.approx((180, 180))


def test_north_is_up_and_east_is_right():
    x, y = radar.marker_pixel(63.0, 27.9, 62.9, 27.7, 50, 360)
    assert x > 180 and y < 180


def test_marker_offset_survives_centre_snapping():
    """Snapping the tile centre must not move the marker off the rider."""
    lat, lon, size, radius = 62.93, 27.71, 360, 50
    clat, clon = radar.snap_centre(lat, lon)
    x, y = radar.marker_pixel(lat, lon, clat, clon, radius, size)
    s, w, n, e = radar.bbox(clat, clon, radius)
    assert w + x / size * (e - w) == pytest.approx(lon)
    assert n - y / size * (n - s) == pytest.approx(lat)


def test_radius_snaps_to_an_offered_value():
    assert [radar.snap_radius(r) for r in (10, 30, 60, 90, 150)] == [25, 25, 50, 100, 100]


def test_latest_frame_is_the_end_of_the_time_dimension():
    xml = ('<Layer><Name>other</Name></Layer><Layer><Name>suomi_dbz_eureffin</Name>'
           '<Dimension name="time" default="current" units="ISO8601">'
           '2026-09-28T13:25:00.000Z/2026-10-05T13:20:00.000Z/PT5M</Dimension></Layer>')
    assert radar.parse_latest_frame(xml) == datetime(2026, 10, 5, 13, 20, tzinfo=timezone.utc)


def test_missing_layer_is_an_upstream_error_not_a_crash():
    with pytest.raises(FMIError):
        radar.parse_latest_frame("<Layer><Name>nothing</Name></Layer>")


def test_draw_returns_a_small_palette_png_of_the_same_size():
    base = io.BytesIO()
    Image.new("RGB", (360, 360), (128, 128, 128)).save(base, "PNG")
    png = radar.draw(base.getvalue(), 180, 180, datetime(2026, 10, 5, 13, 20, tzinfo=timezone.utc))
    image = Image.open(io.BytesIO(png))
    assert image.size == (360, 360) and image.mode == "P"
    assert len(png) < 10_000


# --- tile size: the Edge's phone link fails on a large image ----------------

def _rainy_base(size=420):
    """A tile full of fine-grained rain: a random one of 32 colours per pixel, which a PNG
    cannot squeeze (the real dense-rain tile was ~48 kB)."""
    import random
    rng = random.Random(7)
    colours = [(i * 8 % 256, (i * 37) % 256, (i * 91) % 256) for i in range(32)]
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = rng.choice(colours)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_a_tile_full_of_rain_is_kept_small():
    when = datetime(2026, 10, 9, 5, 40, tzinfo=timezone.utc)
    base = _rainy_base()
    sharp = radar._encode(Image.open(io.BytesIO(base)).convert("RGB"), 1, 210, 210, when)
    assert len(sharp) > radar.MAX_TILE_BYTES            # the problem: too big for the Edge
    out = radar.draw(base, 210, 210, when)
    assert Image.open(io.BytesIO(out)).size == (420, 420)
    assert len(out) <= radar.MAX_TILE_BYTES


def test_a_quiet_tile_keeps_full_sharpness():
    flat = Image.new("RGB", (420, 420), (110, 110, 110))
    buf = io.BytesIO()
    flat.save(buf, format="PNG")
    when = datetime(2026, 10, 9, 5, 40, tzinfo=timezone.utc)
    assert radar.draw(buf.getvalue(), 210, 210, when) == radar._encode(flat, 1, 210, 210, when)
