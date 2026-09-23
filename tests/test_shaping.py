from app.main import _age_seconds, _latest, _nearest_station_rows


def test_latest_takes_most_recent_non_null_per_parameter():
    """Stations drop sensors they do not have and report on different cadences.

    Harmaja returns null cloudheight and no precipitation at all, while its wind
    updates every minute (RESEARCH.md §3) — so the collapse must be
    per-parameter, not per-row.
    """
    rows = [
        {"epochtime": 100, "temperature": 14.0, "windgust": 11.0},
        {"epochtime": 200, "temperature": 14.5, "windgust": None},
    ]
    out, _ = _latest(rows, ["temperature", "windgust"])
    assert out["temperature"] == 14.5
    assert out["windgust"] == 11.0, "should fall back to the older non-null gust"
    assert out["epochtime"] == 200


def test_each_field_carries_its_own_measurement_time():
    """The point of per-field timestamps: one age for the reading would be wrong.

    Here the gust is 100 seconds older than the temperature, and saying both
    were measured at 200 would overstate the gust's freshness.
    """
    rows = [
        {"epochtime": 100, "temperature": 14.0, "windgust": 11.0},
        {"epochtime": 200, "temperature": 14.5, "windgust": None},
    ]
    _, at = _latest(rows, ["temperature", "windgust"])
    assert at["temperature"] == 200
    assert at["windgust"] == 100


def test_absent_sensor_gets_no_timestamp():
    rows = [{"epochtime": 1, "temperature": 3.0, "precipitation1h": None}]
    out, at = _latest(rows, ["temperature", "precipitation1h"])
    assert out["precipitation1h"] is None
    assert "precipitation1h" not in at, "a field with no reading must not claim a time"
    assert at["temperature"] == 1


def test_latest_handles_no_rows():
    out, at = _latest([], ["temperature"])
    assert out == {"temperature": None}
    assert at == {}


def test_age_is_never_negative():
    assert _age_seconds(None) is None
    assert _age_seconds(2**31) == 0  # a future timestamp clamps rather than going negative


# --- cache bounds -----------------------------------------------------------

def test_cache_evicts_expired_entries_without_being_read():
    """The leak: an entry used to survive until its own key was read again."""
    from app.cache import TTLCache

    c = TTLCache(max_entries=4)
    for i in range(3):
        c.set(f"stale:{i}", i, ttl=0)          # already expired
    assert len(c) == 3
    for i in range(4):                          # writing past the cap sweeps
        c.set(f"live:{i}", i, ttl=600)
    assert len(c) <= 4
    assert c.get("stale:0") is None
    assert c.get("live:3") == 3


def test_cache_is_capped_under_unique_keys():
    """Distinct keys are caller-controlled, so growth must be bounded."""
    from app.cache import TTLCache

    c = TTLCache(max_entries=8)
    for i in range(500):
        c.set(f"fc:place-{i}", i, ttl=3600)
    assert len(c) <= 8


# --- cache key / query agreement -------------------------------------------

def test_glance_and_observations_share_one_fetch_path():
    """They shared a cache key while asking FMI two different questions."""
    import inspect

    from app import main

    glance = inspect.getsource(main.glance)
    # The glance must not build its own query or its own key.
    assert "timeseries(" not in glance
    assert 'f"obs:' not in glance
    assert "_observation_rows(" in glance
    assert "_station_rows(" in glance

    observations = inspect.getsource(main.observations)
    assert "timeseries(" not in observations
    assert "_observation_rows(" in observations


def test_nearest_station_rows_keeps_one_station():
    """`numberofstations` interleaves stations, so the rows must be narrowed
    before `_latest` collapses them.

    Otherwise a composite gets built from stations tens of kilometres apart —
    here the far station's wind would be glued onto the near station's
    temperature and presented as one place.
    """
    rows = [
        {"epochtime": 100, "stationname": "Near", "distance": 4.5,
         "temperature": 10.0, "windspeedms": None},
        {"epochtime": 100, "stationname": "Far", "distance": 13.7,
         "temperature": 9.0, "windspeedms": 3.0},
    ]
    kept = _nearest_station_rows(rows)
    assert [r["stationname"] for r in kept] == ["Near"]
    out, _ = _latest(kept, ["temperature", "windspeedms"])
    assert out["temperature"] == 10.0
    assert out["windspeedms"] is None, "must not borrow wind from the far station"


def test_nearest_station_rows_passes_through_without_distances():
    """The `fmisid` path targets one station and FMI returns no `distance`."""
    rows = [{"epochtime": 100, "stationname": "Helsinki Harmaja", "temperature": 8.0}]
    assert _nearest_station_rows(rows) == rows
    assert _nearest_station_rows([]) == []
