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
#
# Rebuilt 2026-09-21 from the 149 stations reporting wind, having found the
# hand-written list both short and wrong. It had 22 entries, of which five were
# defective: 101003 "Helsinki Vuosaari satama" silently returned **Harmaja**
# data (the real Vuosaari satama is 151028, and reports no wind); 134252
# "Föglö Degerby" actually reports as Lumparland Långnäs harbour, duplicating
# 151048; and Jussarö, Bogskär and Kristiinankaupunki Majakka are all in FMI's
# registry but return no wind at all — not even empty rows.
#
# The lesson is in the failure mode: a wrong fmisid does not error. It returns
# a different station's readings under the label you chose.
MARINE_STATIONS: tuple[Station, ...] = (
    Station(101783, "Kemi I majakka", 65.385078, 24.095684),
    Station(101846, "Kemi Ajos", 65.673180, 24.515193),
    Station(101784, "Hailuoto Marjaniemi", 65.039750, 24.561180),
    Station(101794, "Oulu Vihreäsaari satama", 65.006370, 25.393248),
    Station(101785, "Raahe Lapaluoto satama", 64.665890, 24.406950),
    Station(101775, "Raahe Nahkiainen", 64.611783, 23.896737),
    Station(101673, "Kalajoki Ulkokalla", 64.330730, 23.446270),
    Station(101661, "Kokkola Tankar", 63.951140, 22.845370),
    Station(101675, "Kokkola Santahaka", 63.838822, 23.097148),
    Station(101660, "Pietarsaari Kallan", 63.751440, 22.522820),
    Station(101464, "Mustasaari Valassaaret", 63.435083, 21.068557),
    Station(101481, "Maalahti Strömmingsbådan", 62.978388, 20.740078),
    Station(101479, "Korsnäs Bredskäret", 62.934880, 21.184850),
    Station(101267, "Pori Tahkoluoto satama", 61.630419, 21.376203),
    Station(101061, "Rauma Kylmäpihlaja", 61.144750, 21.302730),
    Station(101059, "Kustavi Isokari", 60.722198, 21.026810),
    Station(100947, "Turku Rajakari", 60.377880, 22.096400),
    Station(100945, "Kemiönsaari Vänö", 59.869490, 22.193427),
    Station(100924, "Parainen Fagerholm", 60.111626, 21.698278),
    Station(100908, "Parainen Utö", 59.779094, 21.374788),
    Station(100932, "Hanko Russarö", 59.773633, 22.948683),
    Station(100946, "Hanko Tulliniemi", 59.808642, 22.912464),
    Station(100969, "Inkoo Bågaskär", 59.931136, 24.014082),
    Station(108020, "Inkoo Jakobramsjö", 59.994639, 23.995599),
    Station(100997, "Kirkkonummi Mäkiluoto", 59.919823, 24.350229),
    Station(100996, "Helsinki Harmaja", 60.105120, 24.975390),
    Station(105392, "Sipoo Itätoukki", 60.101207, 25.194394),
    Station(101023, "Porvoo Emäsalo", 60.203820, 25.625460),
    Station(101022, "Porvoo Kalbådagrund", 59.985683, 25.598788),
    Station(100683, "Porvoo Kilpilahti satama", 60.303725, 25.549164),
    Station(101039, "Loviisa Orrengrund", 60.274765, 26.447587),
    Station(101030, "Kotka Rankki", 60.375377, 26.958926),
    Station(101231, "Virolahti Koivuniemi", 60.527197, 27.672743),
    Station(100919, "Hammarland Märket", 60.300980, 19.131420),
    Station(100928, "Kumlinge kirkonkylä", 60.258229, 20.746975),
    Station(100917, "Jomala Jomalaby", 60.178236, 19.986864),
    Station(151048, "Lumparland Långnäs satama", 60.115843, 20.297649),
    Station(151029, "Maarianhamina Länsisatama", 60.091359, 19.929101),
    Station(107383, "Maarianhamina Lotsberget", 60.087643, 19.935463),
    Station(100909, "Lemland Nyhamn", 59.959108, 19.953736),
)

# Inland lake stations. Finnish calls a chart of Saimaa a "merikartta" the same
# as one of the Gulf of Finland, so these sit under the same "sea station"
# setting rather than a separate concept — and the big lakes carry a lot of
# boats. No wave buoys serve them, which is why buoy selection is distance-
# capped rather than nearest-at-any-distance.
LAKE_STATIONS: tuple[Station, ...] = (
    Station(101628, "Liperi Tuiskavanluoto", 62.546010, 29.668180),
    Station(101436, "Rantasalmi Rukkasluoto", 62.063020, 28.566180),
    Station(101421, "Varkaus Kosulanniemi", 62.322213, 27.907850),
    Station(101580, "Kuopio Ritoniemi", 62.798920, 27.904950),
    Station(101311, "Tampere Siilinkari", 61.517566, 23.753878),
    Station(101362, "Luhanka Judinsalo", 61.704484, 25.505293),
    Station(150168, "Puumala kirkonkylä", 61.522420, 28.184910),
    Station(101252, "Lappeenranta Hiekkapakka", 61.198200, 28.473080),
    Station(101537, "Viitasaari Haapaniemi", 63.082247, 25.858617),
    Station(101572, "Kuopio Maaninka", 63.143426, 27.313171),
    Station(101756, "Sotkamo Kuolaniemi", 64.111972, 28.336389),
    Station(101636, "Lieksa Lampela", 63.321083, 30.045778),
    Station(101254, "Parikkala Koitsanlahti", 61.444667, 29.461083),
    Station(101705, "Pyhäjärvi Ojakylä", 63.735886, 25.705732),
)

#: Everything selectable as a "sea station", coast and lake alike.
SEA_STATIONS: tuple[Station, ...] = MARINE_STATIONS + LAKE_STATIONS


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

_BY_ID = {s.fmisid: s for s in SEA_STATIONS + WAVE_BUOYS}


def by_id(fmisid: int) -> Station | None:
    return _BY_ID.get(fmisid)


def nearest(stations: tuple[Station, ...], lat: float, lon: float) -> Station:
    return min(stations, key=lambda s: haversine_km(lat, lon, s.lat, s.lon))


def by_distance(stations: tuple[Station, ...], lat: float, lon: float) -> list[tuple[Station, float]]:
    """Stations with their distance, nearest first."""
    ranked = [(s, haversine_km(lat, lon, s.lat, s.lon)) for s in stations]
    ranked.sort(key=lambda pair: pair[1])
    return ranked
