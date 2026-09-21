from app import stations


def test_registries_are_populated_and_ids_unique():
    assert len(stations.MARINE_STATIONS) >= 35
    assert len(stations.LAKE_STATIONS) >= 10
    assert len(stations.WAVE_BUOYS) == 9
    ids = [s.fmisid for s in stations.SEA_STATIONS + stations.WAVE_BUOYS]
    assert len(ids) == len(set(ids)), "duplicate fmisid in the station registry"


def test_marine_stations_that_place_lookup_gets_wrong_are_present():
    """The whole reason these lists exist (RESEARCH.md §11).

    place=Isokari returns Pori airport, and Kalbådagrund/Märket/Valassaaret are
    "Unknown location" — but all have stable ids, so the app selects them by
    fmisid.
    """
    for fmisid in (101059, 101022, 100919, 101464):
        station = stations.by_id(fmisid)
        assert station is not None
        assert station in stations.MARINE_STATIONS


def test_stations_that_report_no_wind_are_not_offered():
    """Dropped 2026-09-21 after checking them against live data.

    All four are real places and three are in FMI's own station registry, which
    is what made them plausible in a hand-written list. None of them returns
    wind: Jussarö, Bogskär and Kristiinankaupunki Majakka give not a single
    reading over six hours, and 101003 was never Vuosaari at all — it returns
    **Harmaja's** data, so the list silently offered the same station twice
    under two names.

    Kept as a test because the failure mode is the dangerous part: a wrong
    fmisid does not error, it answers with somebody else's weather.
    """
    for fmisid in (100965, 100921, 101268, 101003):
        assert stations.by_id(fmisid) is None


def test_lake_stations_are_selectable_as_sea_stations():
    """Finnish calls a chart of Saimaa a merikartta too, so the big lakes sit
    under the same setting rather than a separate concept."""
    tampere = stations.by_id(101311)          # Näsijärvi
    assert tampere is not None
    assert tampere in stations.LAKE_STATIONS
    assert tampere in stations.SEA_STATIONS
    assert tampere not in stations.MARINE_STATIONS


def test_nearest_buoy_to_harmaja_is_suomenlinna():
    harmaja = stations.by_id(100996)
    nearest = stations.nearest(stations.WAVE_BUOYS, harmaja.lat, harmaja.lon)
    assert nearest.fmisid == 103976


def test_by_distance_is_ordered_and_matches_verified_figures():
    harmaja = stations.by_id(100996)
    ranked = stations.by_distance(stations.WAVE_BUOYS, harmaja.lat, harmaja.lon)
    distances = [d for _, d in ranked]
    assert distances == sorted(distances)
    # Verified live 2026-09-20: 2.0 km sheltered, 21.2 km open sea (RESEARCH.md §4).
    assert abs(distances[0] - 2.0) < 0.1
    assert abs(distances[1] - 21.2) < 0.1


def test_inland_stations_are_distinguishable_for_buoy_selection():
    """Buoy auto-selection is switched off by station type, not by distance.

    Distance was the wrong test: it is a proxy for "is this the same body of
    water". Hanko legitimately uses a buoy 119 km away because none sits closer
    to the same sea, while Näsijärvi should get none at any distance.
    """
    assert stations.by_id(101311) in stations.LAKE_STATIONS      # Tampere, Näsijärvi
    assert stations.by_id(100932) not in stations.LAKE_STATIONS  # Hanko Russarö
    assert stations.by_id(100932) in stations.MARINE_STATIONS
