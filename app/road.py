"""Road weather and road surface conditions, for the car client (FIRoadWeather).

Two sources, because neither is sufficient alone (FIRoadWeather/RESEARCH.md §5):

* **FMI** ``producer=road`` on the JSON timeseries endpoint — road surface
  temperature, air temperature, dew point, humidity, visibility, snow depth.
  Numeric and good. What it does *not* give is a categorical road state:
  ``roadcondition``, ``roadconditionseverity``, ``rform``, ``n_man``,
  ``friction`` and ``precipitationtype`` are accepted as parameter names but
  return ``null`` at every station tested, in July and in January alike.
* **Fintraffic Digitraffic** — the categorical layer FMI withholds. ``KELI_1``
  carries a road-state code *with an English description string*, alongside
  freezing point, salt and a 0–12 h road-condition forecast per road section.

Traps handled here, all found against the live services:

* **Unknown parameters hard-error the whole response.** ``producer=road``
  answers a bad parameter name with ``Parameter x for stationtype road not
  found!`` as an HTTP 200 body — not JSON, and not a per-field null the way
  forecast queries behave. One typo therefore loses every field, so the
  parameter list here is pinned to names verified against the live endpoint.
* **Digitraffic 406s without gzip.** ``Accept-Encoding: gzip`` is mandatory on
  every Digitraffic interface. httpx negotiates it by default; it is set
  explicitly anyway so a future transport change cannot silently break it.
* **Digitraffic rate-limits 60 requests/min per IP.** Hence the long TTLs on
  the two metadata calls, which describe geography that changes a few times a
  year rather than a few times an hour.
* **Road weather is absent from WFS entirely.** ``describeStoredQueries``
  returns 151 ids and not one matches "road", so the undocumented
  ``/timeseries`` endpoint is the *only* route to FMI road data — there is no
  documented fallback if it changes.

**Privacy constraint, and it is a hard one.** The caller's coordinates must
never reach a log line, a metrics label, or anything else retrievable. The
Play Data safety declaration for the car app rests on the *ephemeral
processing* exemption — coordinates used to serve the request and never
persisted — and that is only honest if this module keeps it true. Cache keys
here are therefore snapped to a coarse grid (:func:`_snap`), which both blunts
precision and makes the cache actually work for callers standing near each
other.
"""

from __future__ import annotations

import math
from typing import Any

import httpx

from . import config
from .fmi import timeseries
from .geo import haversine_km

DIGITRAFFIC_ATTRIBUTION = "Source: Fintraffic / digitraffic.fi, license CC 4.0 BY"


class RoadDataError(RuntimeError):
    """An upstream road service returned something unusable."""


# --------------------------------------------------------------------------
# FMI road stations
# --------------------------------------------------------------------------

#: Verified against the live endpoint. Every name here returns real values;
#: anything not on this list risks hard-erroring the whole query, so it is a
#: pinned allow-list rather than a wish list.
ROAD_PARAMS = [
    "stationname",
    "fmisid",
    "distance",
    "temperature",
    "roadtemperature",
    "dewpoint",
    "humidity",
    "windspeedms",
    "winddirection",
    "visibility",
    "snowdepth",
    "precipitationamount",
]

#: Accepted as names but null at every station tested, in summer and winter.
#: Listed so nobody re-adds them hoping for different luck.
ROAD_PARAMS_DEAD = (
    "roadcondition",
    "roadconditionseverity",
    "rform",
    "n_man",
    "friction",
    "precipitationtype",
    "ri_10min",
)


async def fmi_road_rows(lat: float, lon: float, stations: int = 3) -> list[dict]:
    """Recent observations from the nearest FMI road weather stations."""
    return await timeseries(
        ROAD_PARAMS,
        producer="road",
        latlon=f"{lat},{lon}",
        numberofstations=stations,
        starttime="-30m",
    )


# --------------------------------------------------------------------------
# Digitraffic
# --------------------------------------------------------------------------

_DT_CLIENT: httpx.AsyncClient | None = None


def dt_client() -> httpx.AsyncClient:
    """Shared client for Digitraffic.

    Separate from the FMI client because the required headers differ:
    Digitraffic wants to be told who is calling, and refuses outright without
    gzip.
    """
    global _DT_CLIENT
    if _DT_CLIENT is None or _DT_CLIENT.is_closed:
        _DT_CLIENT = httpx.AsyncClient(
            timeout=config.HTTP_TIMEOUT,
            follow_redirects=True,
            limits=httpx.Limits(max_connections=10, max_keepalive_connections=5),
            headers={
                "Digitraffic-User": config.DIGITRAFFIC_USER,
                "Accept-Encoding": "gzip",
            },
        )
    return _DT_CLIENT


async def aclose() -> None:
    """Close the shared client. Called from the app's shutdown hook."""
    global _DT_CLIENT
    if _DT_CLIENT is not None and not _DT_CLIENT.is_closed:
        await _DT_CLIENT.aclose()
    _DT_CLIENT = None


async def _dt_get(path: str, **params: Any) -> dict:
    url = f"{config.DIGITRAFFIC_BASE}{path}"
    response = await dt_client().get(url, params={k: v for k, v in params.items() if v is not None})
    if response.status_code == 429:
        raise RoadDataError("digitraffic rate limit reached")
    if response.status_code != 200:
        raise RoadDataError(f"digitraffic {path} {response.status_code}")
    try:
        return response.json()
    except ValueError as exc:
        raise RoadDataError(f"digitraffic {path}: non-JSON response") from exc


def _snap(value: float, grid: float = 0.05) -> float:
    """Round a coordinate onto a grid, for cache keys.

    ~5 km at Finnish latitudes. Coarse enough that a key says little about
    where the caller is, fine enough that it still selects the right stations.
    """
    return round(round(value / grid) * grid, 4)


def _bbox(lat: float, lon: float, pad: float = 0.15) -> dict[str, float]:
    """A snapped bounding box around a point.

    Digitraffic's section endpoints take a bbox but no radius, so the padding
    is chosen to be wide enough to contain a section on any nearby road
    (~17 km north-south) without pulling the whole country.
    """
    slat, slon = _snap(lat, pad), _snap(lon, pad)
    return {
        "xMin": round(slon - pad, 4),
        "yMin": round(slat - pad, 4),
        "xMax": round(slon + pad, 4),
        "yMax": round(slat + pad, 4),
    }


async def dt_stations() -> dict:
    """All road weather station metadata. Geography — changes rarely."""
    return await _dt_get("/api/weather/v1/stations")


async def dt_station_data(station_id: int) -> dict:
    """Live sensor values for one station. 95 sensors on a well-equipped one."""
    return await _dt_get(f"/api/weather/v1/stations/{station_id}/data")


async def dt_sections(bbox: dict[str, float]) -> dict:
    """Forecast-section geometry in a bbox, so sections can be ranked by distance.

    The ``-simple`` variant is deliberate: it aggregates sections coarsely (13
    in a 0.3° box around Helsinki against 110 for the detailed one) and carries
    the ``description`` and ``roadNumber`` a driver can actually recognise.
    """
    return await _dt_get("/api/weather/v1/forecast-sections-simple", **bbox)


async def dt_section_forecasts(bbox: dict[str, float]) -> dict:
    """0–12 h road-condition forecasts for the sections in a bbox."""
    return await _dt_get("/api/weather/v1/forecast-sections-simple/forecasts", **bbox)


# --------------------------------------------------------------------------
# Shaping
# --------------------------------------------------------------------------

#: Digitraffic's own test rigs. Ten of 528, and Fintraffic flag them nowhere
#: in the metadata — ``collectionStatus`` reads ``GATHERING`` exactly like a
#: real station, so the name prefix is the only signal there is. They cluster
#: in Lapland (Utsjoki, Inari, Savukoski, Muonio, Kuhmo, Puolanka), which is
#: precisely where real coverage is thinnest and a wrong pick is most likely:
#: at Utsjoki the nearest "sensor" was ``TEST_st970_Utsjoki_Nuvvus_Lumi``.
_TEST_STATION_PREFIX = "TEST"


def _usable_station(props: dict) -> bool:
    """Whether a station may be offered to a driver as *the* nearby reading."""
    name = (props.get("name") or "").upper()
    if name.startswith(_TEST_STATION_PREFIX):
        return False
    # A station Fintraffic have pulled out of service is not "the nearest
    # sensor" in any useful sense, whatever its coordinates still say.
    return props.get("collectionStatus") != "REMOVED_TEMPORARILY"


def nearest_station(stations: dict, lat: float, lon: float) -> dict | None:
    """The closest usable road weather station, with its distance."""
    best: dict | None = None
    for feature in stations.get("features", []):
        coords = (feature.get("geometry") or {}).get("coordinates") or []
        if len(coords) < 2:
            continue
        props_check = feature.get("properties") or {}
        if not _usable_station(props_check):
            continue
        slon, slat = float(coords[0]), float(coords[1])
        km = haversine_km(lat, lon, slat, slon)
        if best is None or km < best["distance_km"]:
            props = feature.get("properties") or {}
            best = {
                "id": props.get("id") or feature.get("id"),
                "name": props.get("name"),
                "distance_km": km,
            }
    if best is not None:
        best["distance_km"] = round(best["distance_km"], 1)
    return best


def nearest_section(sections: dict, lat: float, lon: float) -> dict | None:
    """The forecast section whose geometry passes closest to the point."""
    best: dict | None = None
    for feature in sections.get("features", sections.get("forecastSections", [])):
        geom = feature.get("geometry") or {}
        coords = geom.get("coordinates") or []
        if geom.get("type") == "MultiLineString":
            points = [p for line in coords for p in line]
        else:
            points = coords
        km = min(
            (haversine_km(lat, lon, float(p[1]), float(p[0])) for p in points if len(p) >= 2),
            default=math.inf,
        )
        if km is math.inf:
            continue
        if best is None or km < best["distance_km"]:
            props = feature.get("properties") or {}
            best = {
                "id": props.get("id") or feature.get("id"),
                "description": props.get("description"),
                "road_number": props.get("roadNumber"),
                "distance_km": km,
            }
    if best is not None:
        best["distance_km"] = round(best["distance_km"], 1)
    return best


#: A station whose road-state sensor is broken says so *in the description*,
#: and there is no separate status field to read it from. Seen in the car on
#: 2026-09-22: `vt3_Helsinki_Pirkkola` returned "The sensor has a fault" where
#: a surface state belongs, and the app printed it as one.
_FAULT_MARKERS = ("fault", "error")


def is_fault(sensor: dict | None) -> bool:
    """Whether a sensor is reporting its own failure rather than a reading.

    Matched on the **English** description on purpose: it is always present,
    whereas matching the localised one would need a phrase per language and
    would quietly stop working the day a translation changed.
    """
    if not sensor:
        return False
    text = (sensor.get("description_en") or "").lower()
    return any(marker in text for marker in _FAULT_MARKERS)


def sensor_map(station_data: dict, lang: str = "en") -> dict[str, dict]:
    """Sensor name → {value, unit, description}, for the sensors we care about.

    Digitraffic publish `sensorValueDescriptionFi` alongside the English one
    and the proxy used to drop it, which put "The sensor has a fault" into an
    otherwise Finnish car UI. There is **no Swedish** field, so `sv` falls back
    to English rather than to Finnish — a Swedish speaker reads English more
    readily than Finnish, and FIRoadWeather/SPEC.md §3 records the choice.
    """
    field = "sensorValueDescriptionFi" if lang == "fi" else "sensorValueDescriptionEn"
    out: dict[str, dict] = {}
    for sensor in station_data.get("sensorValues", []):
        name = sensor.get("name")
        if not name:
            continue
        english = sensor.get("sensorValueDescriptionEn")
        out[name] = {
            "value": sensor.get("value"),
            "unit": sensor.get("unit"),
            "description": sensor.get(field) or english,
            # Kept regardless of language so fault detection has one thing to
            # match against.
            "description_en": english,
        }
    return out


def ice_risk(road_temp_c: float | None, dew_point_c: float | None,
             air_temp_c: float | None) -> dict:
    """Derived frost and ice risk.

    The two numbers that decide it, and neither is air temperature:

    * **Surface at or below freezing.** Air above zero says nothing — the road
      radiates heat to the sky and runs colder, and bridges and open stretches
      run colder still.
    * **Surface at or below the dew point.** Moisture then condenses onto the
      surface rather than staying in the air. Below freezing that is hoar frost
      or black ice, and it forms on a road that looks dry.

    Returned as a level plus the reason, so the client shows *why* rather than
    a bare colour. ``unknown`` is honest when the station did not report; it is
    not the same as ``none``.
    """
    if road_temp_c is None:
        return {"level": "unknown", "reason": "no road surface temperature nearby"}

    freezing = road_temp_c <= 0.0
    condensing = dew_point_c is not None and road_temp_c <= dew_point_c

    if freezing and condensing:
        return {"level": "high",
                "reason": "surface below freezing and at the dew point — frost or black ice"}
    if freezing:
        return {"level": "moderate", "reason": "road surface at or below freezing"}
    if road_temp_c <= 2.0 and condensing:
        return {"level": "moderate",
                "reason": "surface near freezing and damp — can ice over quickly"}
    if road_temp_c <= 2.0:
        return {"level": "low", "reason": "road surface near freezing"}
    if air_temp_c is not None and air_temp_c <= 0.0:
        # Air below zero with a warm surface: the surface is losing its margin.
        return {"level": "low", "reason": "air below freezing, surface still above"}
    return {"level": "none", "reason": "road surface well above freezing"}
