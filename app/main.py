"""FIWeatherWatch backend.

Serves reshaped FMI data to the Garmin watch app. Every response is kept small
deliberately: Connect IQ starts failing somewhere around 32 kB and must hold
roughly twice the payload in memory to parse it (RESEARCH.md §10).

The same image runs in two places (RESEARCH.md §19): internally with
``ENABLE_CHARTS=true`` for the prototype data-graphics site, and on public-vm
with charts off for production.
"""

from __future__ import annotations

import time
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import Any, AsyncIterator

from fastapi import FastAPI, HTTPException, Query

from . import config, stations
from .cache import cache
from .fmi import (
    FMIError,
    UnknownPlace,
    aclose as fmi_aclose,
    resolve_place,
    timeseries,
    wave_observations,
    wfs_simple,
    wfs_timevaluepair,
)
from .geo import bearing_deg, compass_8, haversine_km

@asynccontextmanager
async def _lifespan(_: FastAPI) -> AsyncIterator[None]:
    """Close the shared upstream client on the way out."""
    yield
    await fmi_aclose()


app = FastAPI(
    lifespan=_lifespan,
    title="FIWeatherWatch backend",
    version="0.1.0",
    description="FMI open data, reshaped for a Garmin watch. Data: "
    "Finnish Meteorological Institute, CC BY 4.0.",
)

ATTRIBUTION = "Finnish Meteorological Institute, CC BY 4.0"



async def _resolve(place: str) -> tuple[float, float, str]:
    """Coordinates for a place, with the failure cached too.

    An unknown name costs four upstream calls — `resolve_place` tries every
    gazetteer in turn — and nothing stopped a caller repeating it. Negative
    results are cached for a spell so a typo, or a loop of them, is paid for
    once rather than every time.
    """
    hit = cache.get(f"geo:{place}")
    if hit is not None:
        if hit == "unknown":
            raise UnknownPlace(place)
        return hit
    try:
        found = await cache.aget_or_set(f"geo:{place}", 86400, lambda: resolve_place(place))
    except UnknownPlace:
        cache.set(f"geo:{place}", "unknown", config.TTL_UNKNOWN_PLACE)
        raise
    return found

# Forecast parameters. Gust is `hourlymaximumgust` on this side (RESEARCH.md §2).
_FORECAST_PARAMS = [
    "temperature",
    "smartsymbol",
    # FMI serves the weather description already localised in fi/sv/en, so the
    # app never has to translate symbol codes itself (RESEARCH.md §16).
    "smartsymboltext",
    "windspeedms",
    "hourlymaximumgust",
    "winddirection",
    "windcompass8",
    "precipitation1h",
]

# Observation parameters. Gust is `windgust` here — asking for
# `hourlymaximumgust` returns nulls instead of erroring (RESEARCH.md §2).
_OBSERVATION_PARAMS = [
    "stationname",
    "fmisid",
    "distance",
    "temperature",
    "humidity",
    "pressure",
    "windspeedms",
    "windgust",
    "winddirection",
    "windcompass8",
]


def _latest(rows: list[dict], keys: list[str]) -> tuple[dict[str, Any], dict[str, int]]:
    """Collapse a series to its most recent non-null value per key.

    Returns the values and, alongside them, **the measurement time of each one
    separately**. Stations report parameters on different cadences and drop
    sensors they do not have — Harmaja publishes wind every minute but returns
    null `cloudheight`, and the Suomenlinna buoy reports water temperature every
    5 minutes against waves every 30 (RESEARCH.md §3, Appendix A). A single age
    for the whole reading would therefore be wrong for most of its fields.
    """
    out: dict[str, Any] = {}
    at: dict[str, int] = {}
    for key in keys:
        for row in reversed(rows):
            if row.get(key) is not None:
                out[key] = row[key]
                stamp = row.get("epochtime")
                if stamp is not None:
                    at[key] = int(stamp)
                break
        else:
            out[key] = None
    if rows:
        out["epochtime"] = rows[-1].get("epochtime")
    return out, at


async def _observation_rows(
    place: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    fmisid: int | None = None,
) -> tuple[list[dict], int]:
    """Observation rows for a station, cached.

    The key and the upstream query are built together here on purpose. They
    used to be built separately in each endpoint, and drifted: /v1/glance
    reused this key while asking FMI by `place=` where /v1/observations asks by
    resolved coordinates. Same key, two different questions — whichever ran
    first won, and the place-resolution fix (`lang` changes what resolves at
    all) was silently bypassed half the time.
    """
    key = f"obs:{place}:{lat}:{lon}:{fmisid}"

    async def fetch() -> list[dict]:
        query: dict[str, Any] = {"producer": "opendata", "starttime": "-60m"}
        if fmisid is not None:
            query["fmisid"] = fmisid
        elif place is not None:
            # Resolve the name first, then ask by coordinates — `lang` must not
            # be able to make a valid Finnish place name unresolvable (app/fmi.py).
            plat, plon, _ = await _resolve(place)
            query["latlon"] = f"{plat},{plon}"
        else:
            query["latlon"] = f"{lat},{lon}"
        return await timeseries(_OBSERVATION_PARAMS, **query)

    return await cache.aget_or_set_entry(key, config.TTL_OBSERVATIONS, fetch)


async def _station_rows(fmisid: int) -> tuple[list[dict], int]:
    """Observation rows for a marine station, by fmisid.

    Separate key from :func:`_observation_rows` because marine stations are
    addressed by id, never by name — free-text lookup returns airports for
    several of them (RESEARCH.md §11).
    """

    async def fetch() -> list[dict]:
        return await timeseries(
            _OBSERVATION_PARAMS, producer="opendata", fmisid=fmisid, starttime="-60m"
        )

    return await cache.aget_or_set_entry(
        f"marine:{fmisid}", config.TTL_OBSERVATIONS, fetch
    )


def _age_seconds(epoch: Any) -> int | None:
    if epoch is None:
        return None
    return max(0, int(time.time()) - int(epoch))


def _fail(exc: FMIError) -> HTTPException:
    # An unrecognised place name is the caller's problem, not an upstream
    # outage — returning 502 made a typo look like the service was down.
    if isinstance(exc, UnknownPlace):
        return HTTPException(status_code=404, detail=f"unknown place: {exc}")
    if "Unknown location" in str(exc):
        return HTTPException(status_code=404, detail=str(exc))
    return HTTPException(status_code=502, detail=f"upstream FMI error: {exc}")


@app.get("/healthz")
async def healthz() -> dict:
    return {"ok": True, "version": app.version, "charts": config.ENABLE_CHARTS}


@app.get("/version")
async def version() -> dict:
    """Asset fingerprint, so a deploy can be confirmed past any CDN cache."""
    return {"version": app.version, "assets": globals().get("ASSET_V")}


@app.get("/v1/forecast")
async def forecast(
    place: str | None = Query(None, max_length=config.MAX_PLACE_LEN,
                             description="Place name, geocoded by FMI"),
    lat: float | None = None,
    lon: float | None = None,
    hours: int = Query(48, ge=3, le=240),
    step: int = Query(180, ge=60, le=1440, description="Minutes between points"),
    lang: str = Query("en", pattern="^(fi|sv|en)$"),
) -> dict:
    """Land forecast for a place or point.

    Uses FMI's default producer (`pal_skandinavia`) — the post-processed,
    meteorologist-corrected product shown on ilmatieteenlaitos.fi, not raw
    model output (RESEARCH.md §3).
    """
    if place is None and (lat is None or lon is None):
        place = config.DEFAULT_PLACE
    key = f"fc:{place}:{lat}:{lon}:{hours}:{step}:{lang}"

    async def fetch() -> list[dict]:
        query: dict[str, Any] = {"timestep": step, "hours": hours, "lang": lang}
        if place is not None:
            # Resolve the name first, then ask by coordinates — `lang` must not
            # be able to make a valid Finnish place name unresolvable (app/fmi.py).
            plat, plon, _ = await _resolve(place)
            query["latlon"] = f"{plat},{plon}"
        else:
            query["latlon"] = f"{lat},{lon}"
        return await timeseries(_FORECAST_PARAMS, **query)

    try:
        rows = await cache.aget_or_set(key, config.TTL_FORECAST, fetch)
    except FMIError as exc:
        raise _fail(exc) from exc
    return {"place": place, "attribution": ATTRIBUTION, "points": rows}


@app.get("/v1/observations")
async def observations(
    place: str | None = Query(None, max_length=config.MAX_PLACE_LEN),
    lat: float | None = None,
    lon: float | None = None,
    fmisid: int | None = Query(None, description="Preferred for marine stations"),
) -> dict:
    """Current conditions from a station.

    Marine stations must be selected by `fmisid`: free-text lookup silently
    returns airports for several of them (RESEARCH.md §11).
    """
    if fmisid is None and place is None and (lat is None or lon is None):
        place = config.DEFAULT_PLACE
    try:
        rows, retrieved = await _observation_rows(place, lat, lon, fmisid)
    except FMIError as exc:
        raise _fail(exc) from exc
    if not rows:
        raise HTTPException(status_code=404, detail="no observations for that location")

    current, measured_at = _latest(rows, _OBSERVATION_PARAMS)
    current["age_seconds"] = _age_seconds(current.get("epochtime"))
    # `at` is when FMI measured each field; `retrieved` is when we fetched from
    # FMI, which differs by up to the cache TTL.
    current["at"] = measured_at
    current["retrieved"] = retrieved
    current["attribution"] = ATTRIBUTION
    return current


# Wave-buoy observation parameters. Note ModalWDi is the direction and WHDD is
# directional *spread* — confusing them points the arrow ~180 degrees wrong
# (RESEARCH.md §4).
_BUOY_FIELDS = {
    "WaveHs": "wave_height_m",
    "WTP": "wave_period_s",
    "ModalWDi": "wave_direction_deg",
    "WHDD": "wave_spread_deg",
    "TWATER": "water_temp_c",
}


async def _buoy_reading(lat: float, lon: float, prefer_fmisid: int | None) -> dict | None:
    """Nearest reporting wave buoy, or None if none are in the water.

    Buoys are seasonal (RESEARCH.md §4), so "no reading" is a normal winter
    state rather than an error.
    """
    try:
        observed = await cache.aget_or_set(
            "buoys", config.TTL_MARINE, lambda: wave_observations("-3h")
        )
    except FMIError:
        return None

    candidates = []
    for station in stations.WAVE_BUOYS:
        match = min(
            observed.items(),
            key=lambda kv: haversine_km(station.lat, station.lon, kv[0][0], kv[0][1]),
            default=None,
        )
        if match is None:
            continue
        (blat, blon), readings = match
        # Positions drift slightly between reports; anything within 5 km of a
        # known buoy is that buoy.
        if haversine_km(station.lat, station.lon, blat, blon) > 5.0:
            continue
        if "WaveHs" not in readings:
            continue  # water-temperature-only buoys are not wave buoys today
        candidates.append((station, readings))

    if not candidates:
        return None
    if prefer_fmisid is not None:
        for station, readings in candidates:
            if station.fmisid == prefer_fmisid:
                chosen = (station, readings)
                break
        else:
            chosen = min(candidates, key=lambda c: haversine_km(lat, lon, c[0].lat, c[0].lon))
    else:
        # Nearest, but only if it is near enough to describe the same water.
        # Uncapped, "nearest reporting buoy" hands an inland lake a Baltic buoy
        # hundreds of kilometres away and presents it as local sea state. An
        # explicitly chosen buoy is still honoured at any distance — that is
        # the user saying they know what they are asking for.
        near = min(candidates, key=lambda c: haversine_km(lat, lon, c[0].lat, c[0].lon))
        if haversine_km(lat, lon, near[0].lat, near[0].lon) > config.BUOY_MAX_KM:
            return None
        chosen = near

    station, readings = chosen
    out: dict[str, Any] = {
        "fmisid": station.fmisid,
        "name": station.name,
        "distance_km": round(haversine_km(lat, lon, station.lat, station.lon), 1),
        "measured": True,
    }
    at: dict[str, str] = {}
    for source, target in _BUOY_FIELDS.items():
        entry = readings.get(source)
        out[target] = entry["value"] if entry else None
        if entry:
            # Wave height reports roughly every 30 min while water temperature
            # reports every 5, so these genuinely differ (RESEARCH.md §4).
            at[target] = entry["time"]
    out["at"] = at
    newest = max(at.values()) if at else None
    out["observed_at"] = newest
    # Epoch too: the watch ages readings by subtraction and has no ISO parser.
    if newest:
        try:
            out["observed_epoch"] = int(
                datetime.fromisoformat(newest.replace("Z", "+00:00")).timestamp()
            )
        except ValueError:
            out["observed_epoch"] = None
    return out


@app.get("/v1/marine")
async def marine(
    fmisid: int = Query(config.DEFAULT_SEA_FMISID, description="Marine station id"),
    buoy_fmisid: int | None = Query(None, description="Override; omit for nearest"),
) -> dict:
    """Sea conditions: station wind plus waves.

    Carries a ``mode`` field from day one even though only ``waves`` and
    ``model`` are possible in v1. Sea ice arrives in v1.5 as a third value, and
    shipping the field now makes that a server change plus one render case
    rather than a redesign (RESEARCH.md §16).
    """
    station = stations.by_id(fmisid)
    if station is None or station not in stations.SEA_STATIONS:
        raise HTTPException(status_code=404, detail=f"unknown sea station {fmisid}")

    try:
        rows, retrieved = await _station_rows(fmisid)
    except FMIError as exc:
        raise _fail(exc) from exc

    current, measured_at = _latest(rows, _OBSERVATION_PARAMS) if rows else ({}, {})
    buoy = await _buoy_reading(station.lat, station.lon, buoy_fmisid)

    waves: dict[str, Any] | None = buoy
    mode = "waves"
    if buoy is None:
        # Buoys are out of the water. Fall back to the WAM model at T+0 and say
        # so plainly — this is the normal December-April state in v1, until sea
        # ice lands in v1.5 (RESEARCH.md §16, §18).
        try:
            wam = await timeseries(
                ["SigWaveHeight", "WaveDirection", "WavePeriod"],
                producer="wam",
                latlon=f"{station.lat},{station.lon}",
                starttime="-0h",
                endtime="-0h",
            )
        except FMIError:
            wam = []
        if wam:
            point = wam[-1]
            waves = {
                "name": "WAM model",
                "measured": False,
                "wave_height_m": point.get("SigWaveHeight"),
                "wave_direction_deg": point.get("WaveDirection"),
                "wave_period_s": point.get("WavePeriod"),
                "water_temp_c": None,
                "observed_at": point.get("epochtime"),
            }
            mode = "model"
        else:
            mode = "model"

    return {
        "mode": mode,
        "station": {
            "fmisid": station.fmisid,
            "name": station.name,
            "temperature": current.get("temperature"),
            "windspeedms": current.get("windspeedms"),
            "windgust": current.get("windgust"),
            "winddirection": current.get("winddirection"),
            "windcompass8": current.get("windcompass8"),
            "pressure": current.get("pressure"),
            "age_seconds": _age_seconds(current.get("epochtime")),
            "at": measured_at,
        },
        "waves": waves,
        "retrieved": retrieved,
        "attribution": ATTRIBUTION,
    }


@app.get("/v1/marine-series")
async def marine_series(
    fmisid: int = Query(config.DEFAULT_SEA_FMISID, description="Marine station id"),
    hours: int = Query(12, ge=1, le=48),
) -> dict:
    """Recent wind at a marine station: mean and gust, for a trend line.

    The point of this endpoint is the shape, not the numbers — a rising 12
    hours reads very differently from a falling one at the same current speed.
    /v1/marine deliberately returns only the latest reading because that is all
    the watch can hold; this exists for the web page, which has room.

    Sampled every 20 minutes rather than every reading: Harmaja republishes
    wind once a minute, which is 720 points for a line a few hundred pixels
    wide, and the extra resolution is invisible.
    """
    station = stations.by_id(fmisid)
    if station is None or station not in stations.SEA_STATIONS:
        raise HTTPException(status_code=404, detail=f"unknown sea station {fmisid}")

    async def fetch() -> list[dict]:
        return await timeseries(
            ["windspeedms", "windgust"],
            producer="opendata",
            fmisid=fmisid,
            starttime=f"-{hours}h",
            timestep=20,
        )

    try:
        rows, retrieved = await cache.aget_or_set_entry(
            f"marineseries:{fmisid}:{hours}", config.TTL_OBSERVATIONS, fetch
        )
    except FMIError as exc:
        raise _fail(exc) from exc

    # Rows with neither value are gaps in the record, not zeroes — dropping
    # them keeps a sensor outage from being drawn as a lull.
    points = [
        {
            "t": int(r["epochtime"]),
            "wind": r.get("windspeedms"),
            "gust": r.get("windgust"),
        }
        for r in rows
        if r.get("epochtime") is not None
        and (r.get("windspeedms") is not None or r.get("windgust") is not None)
    ]
    return {
        "station": {"fmisid": station.fmisid, "name": station.name},
        "hours": hours,
        "points": points,
        "retrieved": retrieved,
        "attribution": ATTRIBUTION,
    }


@app.get("/v1/glance")
async def glance(
    place: str = Query(config.DEFAULT_PLACE, max_length=config.MAX_PLACE_LEN),
    fmisid: int = Query(config.DEFAULT_SEA_FMISID),
) -> dict:
    """The two or three numbers the glance draws.

    Kept deliberately tiny: a glance runs in roughly 32 kB shared with the
    background code, and JSON costs several times its raw size once parsed
    (RESEARCH.md §17).
    """
    try:
        # Both go through the shared fetch paths, so the glance sees exactly
        # what the full pages see rather than its own near-miss of the query.
        land_rows, _ = await _observation_rows(place=place)
        sea_rows, _ = await _station_rows(fmisid)
    except FMIError as exc:
        raise _fail(exc) from exc

    land, land_at = _latest(land_rows, _OBSERVATION_PARAMS) if land_rows else ({}, {})
    sea, sea_at = _latest(sea_rows, _OBSERVATION_PARAMS) if sea_rows else ({}, {})
    return {
        "land_temp_c": land.get("temperature"),
        "land_at": land_at.get("temperature"),
        "sea_wind_ms": sea.get("windspeedms"),
        "sea_gust_ms": sea.get("windgust"),
        "sea_wind_dir": sea.get("windcompass8"),
        "sea_at": sea_at.get("windspeedms"),
        "age_seconds": _age_seconds(sea.get("epochtime")),
    }


# --- Prototype data-graphics site -------------------------------------------
# Enabled only on the internal deployment (RESEARCH.md §19). Production runs the
# same image with ENABLE_CHARTS unset, so none of this is routed there.

# --- Web front ends ---------------------------------------------------------
# Two distinct sites, each behind its own flag (RESEARCH.md §19):
#   ENABLE_PUBLIC   the public weather page — what the watch shows, live
#   ENABLE_CHARTS   the internal research explorer — LAN-only, never public
# A deploy with neither flag set is an API and nothing else.

if config.ENABLE_PUBLIC or config.ENABLE_CHARTS:
    from pathlib import Path

    import hashlib
    import re

    from fastapi.responses import HTMLResponse
    from fastapi.staticfiles import StaticFiles

    _HERE = Path(__file__).parent

    def _asset_version() -> str:
        """Short fingerprint of the served assets, used to bust CDN caches.

        Cloudflare caches static files for four hours by default, so a deploy
        would otherwise leave visitors running the previous JavaScript against
        the new HTML — which is exactly how a language selector can appear but
        do nothing. Versioned URLs make a long cache lifetime correct rather
        than dangerous: the URL changes whenever the bytes do.
        """
        digest = hashlib.sha256()
        for path in sorted(_HERE.glob("*/*.js")) + sorted(_HERE.glob("*/*.css")):
            digest.update(path.read_bytes())
        return digest.hexdigest()[:10]

    ASSET_V = _asset_version()

    def _page(name: str) -> HTMLResponse:
        html = (_HERE / name / "index.html").read_text(encoding="utf-8")
        html = re.sub(r'((?:src|href)="/[^"]+?\.(?:js|css))"', r'\1?v=' + ASSET_V + '"', html)
        # The HTML must never be cached, or it keeps pointing at an old version.
        return HTMLResponse(html, headers={"Cache-Control": "no-cache, must-revalidate"})

    @app.get("/v1/stations")
    async def stations_list() -> dict:
        """Sea stations and wave buoys, for the pickers on both pages."""
        return {
            # Grouped so a picker can separate them. Both are "sea stations":
            # Finnish calls a chart of Saimaa a merikartta too.
            "marine_stations": [
                {"fmisid": s.fmisid, "name": s.name, "lat": s.lat, "lon": s.lon}
                for s in stations.MARINE_STATIONS
            ],
            "lake_stations": [
                {"fmisid": s.fmisid, "name": s.name, "lat": s.lat, "lon": s.lon}
                for s in stations.LAKE_STATIONS
            ],
            "wave_buoys": [
                {"fmisid": s.fmisid, "name": s.name, "lat": s.lat, "lon": s.lon}
                for s in stations.WAVE_BUOYS
            ],
        }

    app.mount("/web", StaticFiles(directory=_HERE / "web"), name="web")


if config.ENABLE_CHARTS:


    @app.get("/v1/series")
    async def series(
        params: str = Query(..., description="Comma-separated FMI parameter names"),
        producer: str | None = Query(None, description="Omit for the default forecast producer"),
        fmisid: int | None = None,
        place: str | None = None,
        lat: float | None = None,
        lon: float | None = None,
        start: str = Query(..., description="Absolute ISO time, e.g. 2026-02-01T00:00:00Z"),
        end: str = Query(..., description="Absolute ISO time"),
        step: int = Query(60, ge=10, le=10080, description="Minutes"),
        lang: str = Query("en", pattern="^(fi|sv|en)$"),
    ) -> dict:
        """Arbitrary time series, for exploration only.

        Absolute ``start``/``end`` are required rather than relative offsets:
        relative offsets are unreliable on some producers — ``starttime=-72h``
        on the flash producer returns flashes ending two days early
        (RESEARCH.md §7). Absolute bounds always behave.

        This endpoint is prototype-only and is not sized for the watch.
        """
        query: dict[str, Any] = {"starttime": start, "endtime": end, "timestep": step,
                                 "lang": lang}
        if producer:
            query["producer"] = producer
        if fmisid is not None:
            query["fmisid"] = fmisid
        elif place is not None:
            query["place"] = place
        elif lat is not None and lon is not None:
            query["latlon"] = f"{lat},{lon}"
        else:
            raise HTTPException(status_code=400, detail="need one of fmisid, place, or lat+lon")

        wanted = [p.strip() for p in params.split(",") if p.strip()]
        try:
            rows = await timeseries(wanted, **query)
        except FMIError as exc:
            raise _fail(exc) from exc
        return {"params": wanted, "rows": rows, "attribution": ATTRIBUTION}


    @app.get("/v1/ice-series")
    async def ice_series(
        place: str = Query("Helsinki"),
        start: str = Query(...),
        end: str = Query(...),
    ) -> dict:
        """Sea ice thickness and snow-on-ice for one coastal point.

        WFS-only — no JSON producer exists (RESEARCH.md §18). Readings are
        weekly and seasonal (late November to late April), so an empty result
        outside that window is correct, not a failure.
        """
        try:
            series = await wfs_timevaluepair(
                "fmi::observations::seaice::manual::timevaluepair",
                place=place, starttime=start, endtime=end,
            )
        except FMIError as exc:
            raise _fail(exc) from exc
        rows: dict[str, dict] = {}
        for parameter, points in series.items():
            for point in points:
                row = rows.setdefault(point["time"], {"time": point["time"]})
                row[parameter] = point["value"]
        return {"rows": [rows[k] for k in sorted(rows)], "attribution": ATTRIBUTION}


    @app.get("/v1/buoy-series")
    async def buoy_series(
        fmisid: int = Query(103976),
        start: str = Query(...),
        end: str = Query(...),
    ) -> dict:
        """Wave-buoy time series for one buoy.

        **Not available through the JSON timeseries endpoint at all** — asking
        `producer=opendata` for `WaveHs` returns a full set of null rows rather
        than an error, which is exactly the kind of plausible-looking failure
        this project keeps running into (RESEARCH.md §4). WFS is the only route.

        `bbox` is ignored by this stored query, so every buoy in Finland comes
        back and the requested one is selected by position here.
        """
        buoy = stations.by_id(fmisid)
        if buoy is None or buoy not in stations.WAVE_BUOYS:
            raise HTTPException(status_code=404, detail=f"unknown wave buoy {fmisid}")

        # An unbounded range is genuinely expensive: 1.5 days across all buoys is
        # already ~3 MB of XML.
        try:
            span = datetime.fromisoformat(end.replace("Z", "+00:00")) - datetime.fromisoformat(
                start.replace("Z", "+00:00")
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="start/end must be ISO times") from exc
        if span > timedelta(days=31):
            raise HTTPException(
                status_code=400,
                detail="range too long for buoy data (max 31 days) — the WFS response "
                "grows to tens of megabytes",
            )

        async def fetch() -> list[dict]:
            elements = await wfs_simple(
                "fmi::observations::wave::simple", starttime=start, endtime=end
            )
            rows: dict[str, dict] = {}
            for element in elements:
                if haversine_km(buoy.lat, buoy.lon, element["lat"], element["lon"]) > 5.0:
                    continue
                row = rows.setdefault(element["time"], {"time": element["time"]})
                row[element["parameter"]] = element["value"]
            return [rows[key] for key in sorted(rows)]

        try:
            rows = await cache.aget_or_set(
                f"buoyseries:{fmisid}:{start}:{end}", config.TTL_MARINE, fetch
            )
        except FMIError as exc:
            raise _fail(exc) from exc
        return {"buoy": {"fmisid": buoy.fmisid, "name": buoy.name}, "rows": rows,
                "attribution": ATTRIBUTION}



    @app.get("/charts/")
    async def charts_index() -> HTMLResponse:
        return _page("charts")

    app.mount("/charts", StaticFiles(directory=_HERE / "charts", html=True), name="charts")


if config.ENABLE_PUBLIC:

    @app.get("/")
    async def public_index() -> HTMLResponse:
        return _page("public")

    app.mount("/public", StaticFiles(directory=_HERE / "public", html=True), name="public")


elif config.ENABLE_CHARTS:

    @app.get("/")
    async def charts_root() -> HTMLResponse:
        return _page("charts")
