"""Warnings and road notices, for the car client's third tab.

Two sources, and the second one is the reason the tab is worth having
(FIRoadWeather/RESEARCH.md §5.6):

* **FMI CAP 1.2** — the authoritative severe-weather warnings, as an Atom feed
  rather than WFS. Colour-coded severity, an area polygon per alert, and
  impact text already written in fi/sv/en. Pulled live on 2026-09-22 it held
  six alerts, **all of them marine** and none on land. On its own this tab
  would be blank most days.
* **Fintraffic traffic messages** — road works and traffic announcements.
  632 live in the same check, 617 of them road works. Never empty, and it is
  the road works a driver actually wants: a speed limit, a closed lane or a
  temporary traffic light on the road ahead.

Two traps handled here:

* **The national feed is 1.2 MB.** It has no bbox parameter, so it is fetched
  once, cached, and filtered by distance in process. The client never sees the
  raw feed — the same reduction the forecast sections get.
* **Sea warnings must not reach a road app.** Rather than matching on event
  names, alerts are selected by *point in polygon*: a driver on a road is not
  inside a sea-area polygon. That is also what **WE-1** asks for, which
  requires warnings be relevant to the driver's location rather than national.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from typing import Any, Iterable

from . import config
from .geo import haversine_km
from .road import RoadDataError, _dt_get, dt_client

CAP_FEED = "https://alerts.fmi.fi/cap/feed/atom_{lang}.xml"

#: FMI publish one feed per language; the app's three match exactly.
CAP_LANG = {"fi": "fi-FI", "sv": "sv-FI", "en": "en-GB"}

_ATOM = "{http://www.w3.org/2005/Atom}"
_CAP = "{urn:oasis:names:tc:emergency:cap:1.2}"

#: Beyond this a road work is not on the driver's route in any useful sense.
DEFAULT_RADIUS_KM = 25.0


# --------------------------------------------------------------------------
# FMI CAP
# --------------------------------------------------------------------------

async def fetch_cap(lang: str = "en") -> str:
    response = await dt_client().get(
        CAP_FEED.format(lang=CAP_LANG.get(lang, "en-GB")),
        headers={"User-Agent": config.USER_AGENT},
    )
    if response.status_code != 200:
        raise RoadDataError(f"cap feed {response.status_code}")
    return response.text


def _params(info: ET.Element) -> dict[str, str]:
    out: dict[str, str] = {}
    for p in info.findall(f"{_CAP}parameter"):
        name = p.findtext(f"{_CAP}valueName")
        if name:
            out[name] = p.findtext(f"{_CAP}value") or ""
    return out


def _polygons(area: ET.Element) -> list[list[tuple[float, float]]]:
    """CAP polygons are `lat,lon lat,lon …` — latitude first, unlike GeoJSON."""
    out = []
    for poly in area.findall(f"{_CAP}polygon"):
        points = []
        for pair in (poly.text or "").split():
            try:
                plat, plon = pair.split(",")
                points.append((float(plat), float(plon)))
            except ValueError:
                continue
        if len(points) >= 3:
            out.append(points)
    return out


def point_in_polygon(lat: float, lon: float, ring: list[tuple[float, float]]) -> bool:
    """Ray casting, in degrees.

    Finland is small enough and the CAP polygons coarse enough that treating
    lat/lon as a plane is well inside the error the polygon already carries.
    """
    inside = False
    n = len(ring)
    for i in range(n):
        y1, x1 = ring[i]
        y2, x2 = ring[(i + 1) % n]
        if (y1 > lat) != (y2 > lat):
            xin = x1 + (lat - y1) * (x2 - x1) / ((y2 - y1) or 1e-12)
            if lon < xin:
                inside = not inside
    return inside


def parse_cap(xml: str) -> list[dict]:
    """Every alert in the feed, with its polygons kept for point matching.

    The CAP document is embedded in each Atom entry, so the whole feed is one
    request rather than one per alert.
    """
    root = ET.fromstring(xml)
    alerts: list[dict] = []
    for alert in root.iter(f"{_CAP}alert"):
        info = alert.find(f"{_CAP}info")
        if info is None:
            continue
        params = _params(info)
        rings: list[list[tuple[float, float]]] = []
        areas: list[str] = []
        for area in info.findall(f"{_CAP}area"):
            rings.extend(_polygons(area))
            desc = area.findtext(f"{_CAP}areaDesc")
            if desc:
                areas.append(desc)
        alerts.append({
            "event": info.findtext(f"{_CAP}event"),
            "severity": info.findtext(f"{_CAP}severity"),
            "urgency": info.findtext(f"{_CAP}urgency"),
            "headline": info.findtext(f"{_CAP}headline"),
            "description": info.findtext(f"{_CAP}description"),
            "onset": info.findtext(f"{_CAP}onset"),
            "expires": info.findtext(f"{_CAP}expires"),
            "colour": params.get("color"),
            "impacts": params.get("typicalImpacts"),
            "areas": areas,
            "_rings": rings,
        })
    return alerts


def alerts_at(alerts: Iterable[dict], lat: float, lon: float) -> list[dict]:
    """Only the alerts whose area actually contains the point.

    This is what keeps marine warnings out of a road app without matching on
    event names: a driver is not inside a sea-area polygon.
    """
    out = []
    for a in alerts:
        if any(point_in_polygon(lat, lon, ring) for ring in a["_rings"]):
            out.append({k: v for k, v in a.items() if not k.startswith("_")})
    return out


# --------------------------------------------------------------------------
# Fintraffic traffic messages
# --------------------------------------------------------------------------

#: Road works and announcements. Weight restrictions are excluded: they matter
#: to hauliers, not to a passenger car, and they would crowd the list.
SITUATION_TYPES = ("TRAFFIC_ANNOUNCEMENT", "ROAD_WORK")


async def dt_traffic_messages() -> dict:
    """Every active message nationwide. 1.2 MB, hence the cache above this."""
    return await _dt_get(
        "/api/traffic-message/v1/messages",
        situationType=list(SITUATION_TYPES),
        inactiveHours=0,
        includeAreaGeometry=False,
    )


def _geometry_points(geom: dict | None) -> list[tuple[float, float]]:
    """Every vertex of a Point, LineString, MultiLineString or Polygon.

    Road works are mostly `MultiLineString` — a stretch of road, not a dot —
    so measuring to the nearest vertex is the honest distance. Ranking on the
    first coordinate alone would put a long roadwork that starts 40 km away but
    passes the car below one that never comes close.
    """
    if not geom:
        return []
    kind, coords = geom.get("type"), geom.get("coordinates") or []

    def walk(node: Any) -> Iterable[tuple[float, float]]:
        if (isinstance(node, (list, tuple)) and len(node) >= 2
                and all(isinstance(v, (int, float)) for v in node[:2])):
            yield float(node[1]), float(node[0])
            return
        if isinstance(node, (list, tuple)):
            for child in node:
                yield from walk(child)

    if kind == "Point":
        return list(walk([coords]))
    return list(walk(coords))


def _restrictions(phase: dict) -> list[dict]:
    out = []
    for r in phase.get("restrictions") or []:
        restriction = r.get("restriction") or {}
        out.append({
            "type": r.get("type"),
            "quantity": restriction.get("quantity"),
            "unit": restriction.get("unit"),
        })
    return out


def shape_notice(feature: dict, lat: float, lon: float) -> dict | None:
    """One traffic message, reduced to what a driver can act on."""
    props = feature.get("properties") or {}
    announcements = props.get("announcements") or []
    if not announcements:
        return None
    a = announcements[0]

    points = _geometry_points(feature.get("geometry"))
    if not points:
        return None
    distance = min(haversine_km(lat, lon, plat, plon) for plat, plon in points)

    primary = (((a.get("locationDetails") or {}).get("roadAddressLocation") or {})
               .get("primaryPoint") or {})
    phases = a.get("roadWorkPhases") or []
    restrictions: list[dict] = []
    severity = None
    for phase in phases:
        restrictions.extend(_restrictions(phase))
        severity = severity or phase.get("severity")

    time = a.get("timeAndDuration") or {}
    return {
        "type": props.get("situationType"),
        "title": (a.get("title") or "").strip(),
        "road": (primary.get("roadAddress") or {}).get("road"),
        "road_name": primary.get("roadName"),
        "municipality": primary.get("municipality"),
        "distance_km": round(distance, 1),
        "severity": severity,
        "features": [f.get("name") for f in (a.get("features") or []) if f.get("name")],
        "restrictions": restrictions,
        "starts": time.get("startTime"),
        "ends": time.get("endTime"),
    }


def notices_near(messages: dict, lat: float, lon: float,
                 radius_km: float = DEFAULT_RADIUS_KM, limit: int = 10) -> list[dict]:
    """Nearby road notices, closest first.

    Road works outrank announcements only by distance — a closed lane 2 km away
    matters more than an announcement 20 km away, whatever its category.
    """
    out = []
    for feature in messages.get("features", []):
        notice = shape_notice(feature, lat, lon)
        if notice is not None and notice["distance_km"] <= radius_km:
            out.append(notice)
    out.sort(key=lambda n: n["distance_km"])
    return out[:limit]
