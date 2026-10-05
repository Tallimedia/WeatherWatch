"""Shaping for the bike-computer endpoint (FIBikeWeather/RESEARCH.md §6-7).

An Edge data field wants four numbers and an alert verdict, not a weather
service's worth of JSON. Everything here is pure — no network — so the logic
that decides *when to alert* can be tested against awkward inputs without
waiting for rain.

Source split:

* **MET Norway Nowcast** — rain rate every five minutes for two hours, plus the
  first step's temperature and wind. This is the only forward-looking radar
  product available for Finland (FMI's own radar WMS is past-only).
* **FMI flash producer** — nearest recent lightning.
* **FMI CAP warnings** — official warnings, by point in polygon.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from .geo import bearing_deg, compass_8, haversine_km

#: Bound on the rain series sent to the device. Two hours at five minutes is 24
#: steps; the Nowcast sometimes returns 23. Kept as a ceiling so a format change
#: upstream cannot balloon the payload past what Connect IQ can parse.
MAX_RAIN_STEPS = 26

#: CAP severity in order, used when FMI gives no colour. Colour is preferred:
#: it is what the public sees on the warnings map.
_COLOUR_RANK = {"green": 0, "yellow": 1, "orange": 2, "red": 3}
_SEVERITY_COLOUR = {"minor": "yellow", "moderate": "yellow", "severe": "orange", "extreme": "red"}


def _parse_time(stamp: str) -> datetime:
    return datetime.fromisoformat(stamp.replace("Z", "+00:00"))


def parse_nowcast(doc: dict) -> dict:
    """Reduce a MET Nowcast response to what the bike endpoint needs.

    Only the first step carries temperature, wind and humidity; later steps hold
    ``precipitation_rate`` alone. ``radar_coverage`` is MET's own statement of
    whether radar actually reached the point, and anything other than ``ok``
    means the rain numbers are a guess rather than a measurement.
    """
    props = doc["properties"]
    steps = props.get("timeseries") or []
    if not steps:
        raise ValueError("nowcast: empty timeseries")
    first = steps[0]["data"]["instant"]["details"]

    series: list[tuple[datetime, float]] = []
    for step in steps[:MAX_RAIN_STEPS]:
        rate = step["data"]["instant"]["details"].get("precipitation_rate")
        if rate is None:
            continue
        series.append((_parse_time(step["time"]), float(rate)))

    return {
        "coverage": props.get("meta", {}).get("radar_coverage"),
        "updated": props.get("meta", {}).get("updated_at"),
        "temp_c": first.get("air_temperature"),
        "wind_ms": first.get("wind_speed"),
        "gust_ms": first.get("wind_speed_of_gust"),
        "wind_dir": first.get("wind_from_direction"),
        "series": series,
    }


def minutes_to_rain(series: list[tuple[datetime, float]], threshold_mmh: float) -> int | None:
    """Minutes from the first nowcast step until rain reaches the threshold.

    ``0`` means it is already raining at or above the threshold. ``None`` means
    it stays below the threshold for the whole horizon — the device shows that
    as "dry 2h+", not as a number, so the two cases must stay distinguishable.

    Measured relative to the first step rather than the wall clock: the first
    step is stamped a few minutes after the request, and comparing against
    ``now`` would make "raining now" read as a negative number whenever the
    clocks disagree by a little.
    """
    if not series:
        return None
    t0 = series[0][0]
    for stamp, rate in series:
        if rate >= threshold_mmh:
            return max(0, round((stamp - t0).total_seconds() / 60))
    return None


def rain_tenths(series: list[tuple[datetime, float]]) -> list[int]:
    """The rate series as integer tenths of mm/h, for the device to threshold itself.

    Integers because Monkey C parses them cheaper than floats and a 0.1 mm/h
    resolution is finer than anything a rider can feel. Lets the data field
    re-evaluate a changed setting without another round trip.
    """
    return [round(rate * 10) for _, rate in series]


def nearest_strike(
    flashes: list[dict], lat: float, lon: float, now_epoch: float, max_age_min: float
) -> dict | None:
    """Closest flash inside the recency window, or ``None``.

    Flash rows come from the national feed, so distance is computed here. Rows
    without a position or timestamp are skipped rather than guessed at.
    """
    best: dict | None = None
    for row in flashes:
        flash_lat, flash_lon, when = row.get("lat"), row.get("lon"), row.get("epochtime")
        if flash_lat is None or flash_lon is None or when is None:
            continue
        age_min = (now_epoch - when) / 60
        if age_min > max_age_min or age_min < -2:
            continue
        distance = haversine_km(lat, lon, flash_lat, flash_lon)
        if best is None or distance < best["km"]:
            best = {
                "km": round(distance, 1),
                "dir": compass_8(bearing_deg(lat, lon, flash_lat, flash_lon)),
                "age_min": max(0, round(age_min)),
            }
    return best


def warning_level(alerts: list[dict]) -> dict | None:
    """The most severe alert at the point, reduced to a level and a short label.

    Returns ``None`` when there is nothing at yellow or above. The headline is
    omitted on purpose: a bike computer field has room for a word, and the
    long CAP text would be the largest thing in the payload.
    """
    best: dict | None = None
    best_rank = 0
    for alert in alerts:
        colour = (alert.get("colour") or "").lower()
        if colour not in _COLOUR_RANK:
            colour = _SEVERITY_COLOUR.get((alert.get("severity") or "").lower(), "")
        rank = _COLOUR_RANK.get(colour, 0)
        if rank > best_rank:
            best_rank = rank
            best = {"level": colour, "event": alert.get("event")}
    return best


def round_position(lat: float, lon: float, places: int = 2) -> tuple[float, float]:
    """Snap a position to ~1 km so nearby riders and refreshes share a cache entry.

    The Nowcast grid is itself about a kilometre, so nothing is lost; what is
    gained is that the cache key space stays small however the rider moves.
    """
    return round(lat, places), round(lon, places)


def shape(
    nowcast: dict | None,
    forecast_row: dict | None,
    strike: dict | None,
    warning: dict | None,
    rain_threshold_mmh: float,
    retrieved: int,
) -> dict[str, Any]:
    """Assemble the payload. Every source is optional; absent ones are ``null``.

    A degraded response is more useful on a bike than an error: if the Nowcast
    is down the field can still show temperature and wind from the forecast and
    say it has no rain data.
    """
    out: dict[str, Any] = {
        "temp": None, "wind": None, "gust": None, "wdir": None,
        "rain_now": None, "mtr": None, "rain": [], "step": 5,
        "strike": strike, "warn": warning,
        "src": "none", "retrieved": retrieved,
    }
    if forecast_row:
        out["temp"] = forecast_row.get("temperature")
        out["wind"] = forecast_row.get("windspeedms")
        out["gust"] = forecast_row.get("hourlymaximumgust")
        out["wdir"] = forecast_row.get("winddirection")
        out["src"] = "fmi"
    if nowcast:
        # The Nowcast wins on anything it carries: it is minutes old, the FMI
        # forecast is an hourly grid.
        for key, source in (("temp", "temp_c"), ("wind", "wind_ms"),
                            ("gust", "gust_ms"), ("wdir", "wind_dir")):
            if nowcast.get(source) is not None:
                out[key] = nowcast[source]
        out["src"] = "met"
        if nowcast.get("coverage") == "ok" and nowcast["series"]:
            out["rain_now"] = nowcast["series"][0][1]
            out["mtr"] = minutes_to_rain(nowcast["series"], rain_threshold_mmh)
            out["rain"] = rain_tenths(nowcast["series"])
        else:
            out["src"] = "met-noradar"
    return out
