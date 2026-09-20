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


async def _client() -> httpx.AsyncClient:
    return httpx.AsyncClient(timeout=config.HTTP_TIMEOUT, follow_redirects=True)


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
    async with await _client() as client:
        response = await client.get(config.FMI_TIMESERIES, params=args)
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
    async with await _client() as client:
        response = await client.get(config.FMI_WFS, params=args)
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
