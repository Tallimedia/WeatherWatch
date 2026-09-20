from app.main import _age_seconds, _latest


def test_latest_takes_most_recent_non_null_per_parameter():
    """Stations drop sensors they do not have and report on different cadences.

    Harmaja returns null cloudheight and no precipitation at all, while its wind
    updates off the ten-minute grid (RESEARCH.md Appendix A) — so the collapse
    must be per-parameter, not per-row.
    """
    rows = [
        {"epochtime": 100, "temperature": 14.0, "windgust": 11.0},
        {"epochtime": 200, "temperature": 14.5, "windgust": None},
    ]
    out = _latest(rows, ["temperature", "windgust"])
    assert out["temperature"] == 14.5
    assert out["windgust"] == 11.0, "should fall back to the older non-null gust"
    assert out["epochtime"] == 200


def test_latest_reports_none_for_a_sensor_that_never_appears():
    rows = [{"epochtime": 1, "temperature": 3.0, "precipitation1h": None}]
    assert _latest(rows, ["precipitation1h"])["precipitation1h"] is None


def test_latest_handles_no_rows():
    assert _latest([], ["temperature"]) == {"temperature": None}


def test_age_is_never_negative():
    assert _age_seconds(None) is None
    assert _age_seconds(2**31) == 0  # a future timestamp clamps rather than going negative
