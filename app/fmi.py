"""Client for the Finnish Meteorological Institute's open data.

FMI exposes two interfaces and this module uses both, because neither alone is
enough (RESEARCH.md §2):

* ``/timeseries`` — the SmartMet TimeSeries plugin. Returns JSON, needs no API
  key, and covers forecasts, land/marine observations, waves and sea level.
* ``/wfs`` — the documented interface. Returns GML/XML, and is the *only* way
  to reach wave-buoy observations.

Traps handled here, all found the hard way and documented in RESEARCH.md §2:

* The bare ``time`` field is **local**, not UTC — 12:00 Helsinki is 09:00Z. We
  never request it; we ask for ``epochtime`` and let the client do the rest.
* Values round to integers unless ``precision=double`` is passed.
* Gusts are ``hourlymaximumgust`` in forecasts but ``windgust`` in observations.
* ``bbox`` is silently ignored by the wave stored query, so buoys are filtered
  by distance in :mod:`app.geo` instead.
* ``ModalWDi`` is the wave direction; ``WHDD`` is directional *spread*.
"""

from __future__ import annotations

import re
from typing import Any

import httpx

from . import config

_ELEMENT_RE = re.compile(r"<BsWfs:BsWfsElement\b.*?</BsWfs:BsWfsElement>", re.S)
_NAME_RE = re.compile(r"<BsWfs:ParameterName>(.*?)</BsWfs:ParameterName>", re.S)
_VALUE_RE = re.compile(r"<BsWfs:ParameterValue>(.*?)</BsWfs:ParameterValue>", re.S)
_TIME_RE = re.compile(r"<BsWfs:Time>(.*?)</BsWfs:Time>", re.S)
_POS_RE = re.compile(r"<gml:pos>\s*([-\d.]+)\s+([-\d.]+)", re.S)


class FMIError(RuntimeError):
    """FMI returned something we could not use."""


class UnknownPlace(FMIError):
    """FMI does not recognise the place name — a client error, not an outage."""


# One client for the process, not one per request. A fresh AsyncClient per call
# meant a new connection pool and a new TLS handshake every time, and /v1/marine
# makes two or three upstream calls. Keeping it open lets HTTP/2 and keep-alive
# do their job against a single upstream host.
_CLIENT: httpx.AsyncClient | None = None


def client() -> httpx.AsyncClient:
    global _CLIENT
    if _CLIENT is None or _CLIENT.is_closed:
        _CLIENT = httpx.AsyncClient(
            timeout=config.HTTP_TIMEOUT,
            follow_redirects=True,
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
            headers={"User-Agent": config.USER_AGENT},
        )
    return _CLIENT


async def aclose() -> None:
    """Close the shared client. Called from the app's shutdown hook."""
    global _CLIENT
    if _CLIENT is not None and not _CLIENT.is_closed:
        await _CLIENT.aclose()
    _CLIENT = None


async def timeseries(params: list[str], **query: Any) -> list[dict]:
    """Query the JSON timeseries endpoint.

    ``epochtime`` is always prepended so every row carries an unambiguous UTC
    timestamp, whatever else is asked for.
    """
    requested = ["epochtime", *[p for p in params if p != "epochtime"]]
    args: dict[str, Any] = {
        "format": "json",
        "precision": "double",
        "param": ",".join(requested),
        **{k: v for k, v in query.items() if v is not None},
    }
    response = await client().get(config.FMI_TIMESERIES, params=args)
    if response.status_code != 200:
        raise FMIError(f"timeseries {response.status_code}: {response.text[:200]}")
    body = response.text.strip()
    if not body.startswith("["):
        # FMI reports bad producers and place names as plain text with a 200.
        raise FMIError(f"timeseries: {body[:200]}")
    return response.json()


async def wfs_simple(storedquery_id: str, **query: Any) -> list[dict]:
    """Query a ``BsWfs`` simple-feature stored query and flatten it.

    Returns one dict per observation element, each with ``time``, ``lat``,
    ``lon``, ``parameter`` and ``value``. ``NaN`` values are dropped, which is
    how FMI signals a sensor that is absent rather than merely quiet.
    """
    args: dict[str, Any] = {
        "service": "WFS",
        "version": "2.0.0",
        "request": "getFeature",
        "storedquery_id": storedquery_id,
        **{k: v for k, v in query.items() if v is not None},
    }
    response = await client().get(config.FMI_WFS, params=args)
    if response.status_code != 200:
        raise FMIError(f"wfs {response.status_code}: {response.text[:200]}")

    rows: list[dict] = []
    for chunk in _ELEMENT_RE.findall(response.text):
        value = _VALUE_RE.search(chunk)
        position = _POS_RE.search(chunk)
        name = _NAME_RE.search(chunk)
        stamp = _TIME_RE.search(chunk)
        if not (value and position and name and stamp):
            continue
        raw = value.group(1).strip()
        if raw == "NaN":
            continue
        rows.append(
            {
                "time": stamp.group(1).strip(),
                "lat": float(position.group(1)),
                "lon": float(position.group(2)),
                "parameter": name.group(1).strip(),
                "value": float(raw),
            }
        )
    return rows


async def wave_observations(start: str) -> dict[tuple[float, float], dict]:
    """Latest wave-buoy readings, grouped by buoy position.

    ``bbox`` is deliberately not passed — the stored query ignores it, and
    trusting it returns buoys hundreds of kilometres from the requested point
    (RESEARCH.md §2). Callers filter by distance instead.
    """
    rows = await wfs_simple("fmi::observations::wave::simple", starttime=start)
    latest: dict[tuple[float, float], dict] = {}
    for row in rows:
        key = (row["lat"], row["lon"])
        bucket = latest.setdefault(key, {})
        previous = bucket.get(row["parameter"])
        if previous is None or row["time"] >= previous["time"]:
            bucket[row["parameter"]] = {"value": row["value"], "time": row["time"]}
    return latest


_TVP_SERIES_RE = re.compile(
    r'<wml2:MeasurementTimeseries[^>]*gml:id="[^"]*?-([A-Za-z0-9_]+)"(.*?)</wml2:MeasurementTimeseries>',
    re.S,
)
_TVP_POINT_RE = re.compile(
    r"<wml2:time>(.*?)</wml2:time>\s*<wml2:value>(.*?)</wml2:value>", re.S
)


async def wfs_timevaluepair(storedquery_id: str, **query: Any) -> dict[str, list[dict]]:
    """Query a ``timevaluepair`` stored query, returning one series per parameter.

    Used for sea ice, which has **no JSON producer at all** — verified against
    ``opendata``, ``seaice``, ``icechart`` and others, all of which return either
    an empty list or "Unknown producer name" (RESEARCH.md §18). WFS is the only
    route, so this parser is also the groundwork for the v1.5 ice feature.
    """
    args: dict[str, Any] = {
        "service": "WFS",
        "version": "2.0.0",
        "request": "getFeature",
        "storedquery_id": storedquery_id,
        **{k: v for k, v in query.items() if v is not None},
    }
    response = await client().get(config.FMI_WFS, params=args)
    if response.status_code != 200:
        raise FMIError(f"wfs {response.status_code}: {response.text[:200]}")

    series: dict[str, list[dict]] = {}
    for parameter, body in _TVP_SERIES_RE.findall(response.text):
        points = series.setdefault(parameter, [])
        for stamp, raw in _TVP_POINT_RE.findall(body):
            value = raw.strip()
            if value in {"NaN", ""}:
                continue
            points.append({"time": stamp.strip(), "value": float(value)})
    for points in series.values():
        points.sort(key=lambda p: p["time"])
    return series


# `lang` changes place *resolution*, not just the language of the output text.
# "Tammisaari" resolves with no lang or lang=fi but is "Unknown location" under
# sv and en; "Hangö" resolves only under sv. So a Finnish place name breaks the
# moment the user switches the page to English, which is exactly backwards for a
# Finnish weather app. Resolution is therefore decoupled from display language:
# find the coordinates by trying each gazetteer in turn, then query by latlon.
_GAZETTEERS = (None, "fi", "sv", "en")


async def resolve_place(place: str) -> tuple[float, float, str]:
    """Coordinates for a place name, tried across every language gazetteer.

    Raises :class:`UnknownPlace` only when no gazetteer knows the name.
    """
    for lang in _GAZETTEERS:
        query: dict[str, Any] = {"place": place, "hours": 1, "timestep": 60}
        if lang:
            query["lang"] = lang
        try:
            rows = await timeseries(["latitude", "longitude", "name"], **query)
        except FMIError:
            continue
        for row in rows:
            if row.get("latitude") is not None and row.get("longitude") is not None:
                return float(row["latitude"]), float(row["longitude"]), row.get("name") or place
    raise UnknownPlace(place)


async def wfs_raw(storedquery_id: str, **query: Any) -> str:
    """The raw XML of a stored query.

    `wfs_simple` and `wfs_timevaluepair` both shape observation results. The
    station metadata document is neither — it is a facility register — so it
    is parsed by its own caller (`stations.parse_station_positions`).
    """
    args = {"service": "WFS", "version": "2.0.0", "request": "getFeature",
            "storedquery_id": storedquery_id, **query}
    response = await client().get(config.FMI_WFS, params=args)
    if response.status_code != 200:
        raise FMIError(f"wfs {storedquery_id} {response.status_code}")
    return response.text
