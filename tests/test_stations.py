from app import stations


def test_registries_are_populated_and_ids_unique():
    assert len(stations.MARINE_STATIONS) >= 20
    assert len(stations.WAVE_BUOYS) == 9
    ids = [s.fmisid for s in stations.MARINE_STATIONS + stations.WAVE_BUOYS]
    assert len(ids) == len(set(ids)), "duplicate fmisid in the station registry"


def test_marine_stations_that_place_lookup_gets_wrong_are_present():
    """The whole reason these lists exist (RESEARCH.md §11).

    place=Bogskär returns Mariehamn airport, place=Isokari returns Pori airport,
    and Kalbådagrund/Märket/Valassaaret are "Unknown location" — but all have
    stable ids, so the app selects them by fmisid.
    """
    for fmisid in (100921, 101059, 101022, 100919, 101464):
        station = stations.by_id(fmisid)
        assert station is not None
        assert station in stations.MARINE_STATIONS


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
