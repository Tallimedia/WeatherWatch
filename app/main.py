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
from datetime import datetime, timedelta
from typing import Any

from fastapi import FastAPI, HTTPException, Query

from . import config, stations
from .cache import cache
from .fmi import (
    FMIError,
    timeseries,
    wave_observations,
    wfs_simple,
    wfs_timevaluepair,
)
from .geo import bearing_deg, compass_8, haversine_km

app = FastAPI(
    title="FIWeatherWatch backend",
    version="0.1.0",
    description="FMI open data, reshaped for a Garmin watch. Data: "
    "Finnish Meteorological Institute, CC BY 4.0.",
)

ATTRIBUTION = "Finnish Meteorological Institute, CC BY 4.0"

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


def _latest(rows: list[dict], keys: list[str]) -> dict[str, Any]:
    """Collapse a series to its most recent non-null value per key.

    Stations report parameters on different cadences and drop sensors they do
    not have — Harmaja returns null `cloudheight` and no precipitation at all
    (RESEARCH.md Appendix A) — so this is per-parameter, not per-row.
    """
    out: dict[str, Any] = {}
    for key in keys:
        for row in reversed(rows):
            if row.get(key) is not None:
                out[key] = row[key]
                break
        else:
            out[key] = None
    if rows:
        out["epochtime"] = rows[-1].get("epochtime")
    return out


def _age_seconds(epoch: Any) -> int | None:
    if epoch is None:
        return None
    return max(0, int(time.time()) - int(epoch))


def _fail(exc: FMIError) -> HTTPException:
    return HTTPException(status_code=502, detail=f"upstream FMI error: {exc}")


@app.get("/healthz")
async def healthz() -> dict:
    return {"ok": True, "version": app.version, "charts": config.ENABLE_CHARTS}


@app.get("/v1/forecast")
async def forecast(
    place: str | None = Query(None, description="Place name, geocoded by FMI"),
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
            query["place"] = place
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
    place: str | None = None,
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
    key = f"obs:{place}:{lat}:{lon}:{fmisid}"

    async def fetch() -> list[dict]:
        query: dict[str, Any] = {"producer": "opendata", "starttime": "-60m"}
        if fmisid is not None:
            query["fmisid"] = fmisid
        elif place is not None:
            query["place"] = place
        else:
            query["latlon"] = f"{lat},{lon}"
        return await timeseries(_OBSERVATION_PARAMS, **query)

    try:
        rows = await cache.aget_or_set(key, config.TTL_OBSERVATIONS, fetch)
    except FMIError as exc:
        raise _fail(exc) from exc
    if not rows:
        raise HTTPException(status_code=404, detail="no observations for that location")

    current = _latest(rows, _OBSERVATION_PARAMS)
    current["age_seconds"] = _age_seconds(current.get("epochtime"))
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
        chosen = min(candidates, key=lambda c: haversine_km(lat, lon, c[0].lat, c[0].lon))

    station, readings = chosen
    out: dict[str, Any] = {
        "fmisid": station.fmisid,
        "name": station.name,
        "distance_km": round(haversine_km(lat, lon, station.lat, station.lon), 1),
        "measured": True,
    }
    for source, target in _BUOY_FIELDS.items():
        entry = readings.get(source)
        out[target] = entry["value"] if entry else None
    stamp = next((r["time"] for r in readings.values()), None)
    out["observed_at"] = stamp
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
    if station is None or station not in stations.MARINE_STATIONS:
        raise HTTPException(status_code=404, detail=f"unknown marine station {fmisid}")

    async def fetch_station() -> list[dict]:
        return await timeseries(
            _OBSERVATION_PARAMS, producer="opendata", fmisid=fmisid, starttime="-60m"
        )

    try:
        rows = await cache.aget_or_set(
            f"marine:{fmisid}", config.TTL_OBSERVATIONS, fetch_station
        )
    except FMIError as exc:
        raise _fail(exc) from exc

    current = _latest(rows, _OBSERVATION_PARAMS) if rows else {}
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
        },
        "waves": waves,
        "attribution": ATTRIBUTION,
    }


@app.get("/v1/glance")
async def glance(
    place: str = Query(config.DEFAULT_PLACE),
    fmisid: int = Query(config.DEFAULT_SEA_FMISID),
) -> dict:
    """The two or three numbers the glance draws.

    Kept deliberately tiny: a glance runs in roughly 32 kB shared with the
    background code, and JSON costs several times its raw size once parsed
    (RESEARCH.md §17).
    """
    try:
        land_rows = await cache.aget_or_set(
            f"obs:{place}:None:None:None",
            config.TTL_OBSERVATIONS,
            lambda: timeseries(_OBSERVATION_PARAMS, producer="opendata",
                               place=place, starttime="-60m"),
        )
        sea_rows = await cache.aget_or_set(
            f"marine:{fmisid}",
            config.TTL_OBSERVATIONS,
            lambda: timeseries(_OBSERVATION_PARAMS, producer="opendata",
                               fmisid=fmisid, starttime="-60m"),
        )
    except FMIError as exc:
        raise _fail(exc) from exc

    land = _latest(land_rows, _OBSERVATION_PARAMS) if land_rows else {}
    sea = _latest(sea_rows, _OBSERVATION_PARAMS) if sea_rows else {}
    return {
        "land_temp_c": land.get("temperature"),
        "sea_wind_ms": sea.get("windspeedms"),
        "sea_gust_ms": sea.get("windgust"),
        "sea_wind_dir": sea.get("windcompass8"),
        "age_seconds": _age_seconds(sea.get("epochtime")),
    }


# --- Prototype data-graphics site -------------------------------------------
# Enabled only on the internal deployment (RESEARCH.md §19). Production runs the
# same image with ENABLE_CHARTS unset, so none of this is routed there.

if config.ENABLE_CHARTS:
    from pathlib import Path

    from fastapi.responses import FileResponse
    from fastapi.staticfiles import StaticFiles

    _CHARTS_DIR = Path(__file__).parent / "charts"

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

    @app.get("/v1/buoys")
    async def buoy_registry() -> dict:
        """The buoy and marine-station lists, so the page can build its pickers."""
        return {
            "marine_stations": [
                {"fmisid": s.fmisid, "name": s.name, "lat": s.lat, "lon": s.lon}
                for s in stations.MARINE_STATIONS
            ],
            "wave_buoys": [
                {"fmisid": s.fmisid, "name": s.name, "lat": s.lat, "lon": s.lon}
                for s in stations.WAVE_BUOYS
            ],
        }

    @app.get("/")
    async def charts_index() -> FileResponse:
        return FileResponse(_CHARTS_DIR / "index.html")

    app.mount("/charts", StaticFiles(directory=_CHARTS_DIR, html=True), name="charts")
