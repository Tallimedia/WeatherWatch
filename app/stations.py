"""Curated station lists, keyed on FMI station id (fmisid).

Free-text place lookup is unusable for marine stations (RESEARCH.md §11):
`place=Bogskär` resolves to Mariehamn *airport*, `place=Isokari` to Pori
airport 18.6 km inland, and Kalbådagrund/Märket/Valassaaret return "Unknown
location" despite all existing with stable ids. So the app picks stations from
these lists by fmisid and never by name.

Source: fmi::ef::stations (439 stations) and
fmi::observations::wave::multipointcoverage, both read live on 2026-09-20.
"""

from __future__ import annotations
from dataclasses import dataclass

from .geo import haversine_km


@dataclass(frozen=True)
class Station:
    fmisid: int
    name: str
    lat: float
    lon: float


# Coastal and lighthouse weather stations — wind, gusts, air temperature,
# pressure. These do NOT report waves or water temperature; that is the buoy
# network below (RESEARCH.md §4).
MARINE_STATIONS: tuple[Station, ...] = (
    Station(100996, "Helsinki Harmaja", 60.105120, 24.975390),
    Station(101003, "Helsinki Vuosaari satama", 60.208670, 25.195900),
    Station(101022, "Porvoo Kalbådagrund", 59.985683, 25.598788),
    Station(101023, "Porvoo Emäsalo", 60.203820, 25.625460),
    Station(101039, "Loviisa Orrengrund", 60.274765, 26.447587),
    Station(101030, "Kotka Rankki", 60.375377, 26.958926),
    Station(100932, "Hanko Russarö", 59.773633, 22.948683),
    Station(100965, "Raasepori Jussarö", 59.820758, 23.573090),
    Station(100908, "Parainen Utö", 59.779094, 21.374788),
    Station(100921, "Kökar Bogskär", 59.504544, 20.347475),
    Station(100928, "Kumlinge kirkonkylä", 60.258229, 20.746975),
    Station(134252, "Föglö Degerby", 60.031883, 20.384817),
    Station(100919, "Hammarland Märket", 60.300980, 19.131420),
    Station(101059, "Kustavi Isokari", 60.722198, 21.026810),
    Station(101061, "Rauma Kylmäpihlaja", 61.144750, 21.302730),
    Station(101268, "Kristiinankaupunki Majakka", 62.203240, 21.169830),
    Station(101464, "Mustasaari Valassaaret", 63.435083, 21.068557),
    Station(101661, "Kokkola Tankar", 63.951140, 22.845370),
    Station(101673, "Kalajoki Ulkokalla", 64.330730, 23.446270),
    Station(101775, "Raahe Nahkiainen", 64.611783, 23.896737),
    Station(101784, "Hailuoto Marjaniemi", 65.039750, 24.561180),
    Station(101783, "Kemi I majakka", 65.385078, 24.095684),
)

# Wave buoys. Seasonal — lifted out of the water roughly December to April
# (RESEARCH.md §4), so "reporting" must always be checked, never assumed.
WAVE_BUOYS: tuple[Station, ...] = (
    Station(103976, "Helsinki Suomenlinna aaltopoiju", 60.123330, 24.972830),
    Station(134221, "Suomenlahti aaltopoiju", 59.965000, 25.235000),
    Station(108495, "Loviisa Orrengrund aaltopoiju", 60.233300, 26.391600),
    Station(134220, "Pohjois-Itämeri aaltopoiju", 59.248170, 20.998330),
    Station(134246, "Selkämeri aaltopoiju", 61.800100, 20.232670),
    Station(104600, "Pori Kaijakari", 61.621600, 21.387400),
    Station(137228, "Perämeri aaltopoiju", 64.684100, 23.238000),
    Station(103808, "Kalajoki Maakalla", 64.294800, 23.550600),
    Station(103807, "Oulu Santapankki", 65.180830, 25.032500),
)

_BY_ID = {s.fmisid: s for s in MARINE_STATIONS + WAVE_BUOYS}


def by_id(fmisid: int) -> Station | None:
    return _BY_ID.get(fmisid)


def nearest(stations: tuple[Station, ...], lat: float, lon: float) -> Station:
    return min(stations, key=lambda s: haversine_km(lat, lon, s.lat, s.lon))


def by_distance(stations: tuple[Station, ...], lat: float, lon: float) -> list[tuple[Station, float]]:
    """Stations with their distance, nearest first."""
    ranked = [(s, haversine_km(lat, lon, s.lat, s.lon)) for s in stations]
    ranked.sort(key=lambda pair: pair[1])
    return ranked
