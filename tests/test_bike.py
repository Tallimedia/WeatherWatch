"""Bike endpoint shaping — the alert logic, exercised without waiting for rain.

Every live check of the Nowcast so far happened on a dry day, so the rain-onset
branches are only ever covered here.
"""

from datetime import datetime, timedelta, timezone

from app import bike, warnings as warn

T0 = datetime(2026, 10, 5, 13, 25, tzinfo=timezone.utc)


def _series(*rates: float) -> list[tuple[datetime, float]]:
    return [(T0 + timedelta(minutes=5 * i), r) for i, r in enumerate(rates)]


def _doc(rates, coverage="ok"):
    steps = []
    for i, r in enumerate(rates):
        details = {"precipitation_rate": r}
        if i == 0:
            details.update(air_temperature=9.5, wind_speed=4.0, wind_speed_of_gust=9.0,
                           wind_from_direction=200.0)
        stamp = (T0 + timedelta(minutes=5 * i)).strftime("%Y-%m-%dT%H:%M:%SZ")
        steps.append({"time": stamp, "data": {"instant": {"details": details}}})
    return {"properties": {"meta": {"radar_coverage": coverage,
                                    "updated_at": "2026-10-05T13:22:46Z"},
                           "timeseries": steps}}


# --- minutes to rain -------------------------------------------------------

def test_already_raining_is_zero_not_none():
    assert bike.minutes_to_rain(_series(1.2, 0, 0), 0.5) == 0


def test_rain_arriving_reports_the_first_step_at_threshold():
    assert bike.minutes_to_rain(_series(0, 0, 0.2, 0.6, 2.0), 0.5) == 15


def test_light_rain_below_the_threshold_does_not_count():
    assert bike.minutes_to_rain(_series(0, 0.3, 0.4, 0.3), 0.5) is None


def test_lowering_the_threshold_catches_the_same_drizzle():
    assert bike.minutes_to_rain(_series(0, 0.3, 0.4, 0.3), 0.1) == 5


def test_a_threshold_equal_to_the_rate_counts():
    assert bike.minutes_to_rain(_series(0, 0.5), 0.5) == 5


def test_empty_series_is_none():
    assert bike.minutes_to_rain([], 0.5) is None


# --- nowcast parsing -------------------------------------------------------

def test_parse_takes_first_step_values_and_the_whole_series():
    parsed = bike.parse_nowcast(_doc([0.0, 0.0, 0.8]))
    assert parsed["temp_c"] == 9.5 and parsed["gust_ms"] == 9.0
    assert [r for _, r in parsed["series"]] == [0.0, 0.0, 0.8]
    assert parsed["coverage"] == "ok"


def test_parse_caps_the_series_length():
    parsed = bike.parse_nowcast(_doc([0.0] * 60))
    assert len(parsed["series"]) == bike.MAX_RAIN_STEPS


def test_rain_is_sent_as_integer_tenths():
    assert bike.rain_tenths(_series(0, 0.04, 0.5, 12.34)) == [0, 0, 5, 123]


# --- shaping ---------------------------------------------------------------

def test_no_radar_is_not_reported_as_dry():
    """The case that matters: a rider must not read 'no data' as 'no rain'."""
    out = bike.shape(bike.parse_nowcast(_doc([0.0, 0.0], coverage="no")),
                     None, None, None, 0.5, 1)
    assert out["src"] == "met-noradar"
    assert out["rain"] == [] and out["mtr"] is None and out["rain_now"] is None
    assert out["temp"] == 9.5  # temperature and wind are still good


def test_dry_with_radar_has_a_series_and_no_minutes():
    out = bike.shape(bike.parse_nowcast(_doc([0.0] * 5)), None, None, None, 0.5, 1)
    assert out["rain"] == [0] * 5 and out["mtr"] is None and out["rain_now"] == 0.0


def test_forecast_fills_in_when_the_nowcast_is_down():
    row = {"temperature": 7.0, "windspeedms": 3.0, "hourlymaximumgust": 6.0, "winddirection": 90}
    out = bike.shape(None, row, None, None, 0.5, 1)
    assert out["src"] == "fmi" and out["temp"] == 7.0 and out["rain"] == []


def test_nowcast_overrides_forecast_where_it_has_a_value():
    row = {"temperature": 7.0, "windspeedms": 3.0}
    out = bike.shape(bike.parse_nowcast(_doc([0.0])), row, None, None, 0.5, 1)
    assert out["temp"] == 9.5 and out["wind"] == 4.0


def test_everything_down_still_returns_a_shape():
    out = bike.shape(None, None, None, None, 0.5, 1)
    assert out["src"] == "none" and out["temp"] is None and out["rain"] == []


def test_payload_stays_small():
    import json
    out = bike.shape(bike.parse_nowcast(_doc([1.5] * 24)), None,
                     {"km": 12.3, "dir": "NE", "age_min": 4},
                     {"level": "orange", "event": "Thunderstorm warning"}, 0.5, 1791207668)
    assert len(json.dumps(out)) < 600


# --- lightning -------------------------------------------------------------

NOW = 1_000_000.0


def _flash(lat, lon, age_min):
    return {"lat": lat, "lon": lon, "epochtime": NOW - age_min * 60}


def test_nearest_recent_strike_wins():
    near = _flash(60.30, 24.94, 5)
    far = _flash(61.50, 24.94, 2)
    got = bike.nearest_strike([far, near], 60.17, 24.94, NOW, 20)
    assert got["dir"] == "N" and 13 < got["km"] < 16 and got["age_min"] == 5


def test_old_strikes_are_ignored():
    assert bike.nearest_strike([_flash(60.2, 24.9, 45)], 60.17, 24.94, NOW, 20) is None


def test_strike_rows_without_a_position_are_skipped():
    rows = [{"lat": None, "lon": 24.9, "epochtime": NOW}, {"epochtime": NOW}]
    assert bike.nearest_strike(rows, 60.17, 24.94, NOW, 20) is None


# --- warnings --------------------------------------------------------------

def test_highest_colour_wins():
    got = bike.warning_level([{"colour": "yellow", "event": "Wind"},
                              {"colour": "red", "event": "Storm"}])
    assert got == {"level": "red", "event": "Storm"}


def test_severity_is_used_when_there_is_no_colour():
    got = bike.warning_level([{"colour": None, "severity": "Severe", "event": "Rain"}])
    assert got["level"] == "orange"


def test_no_alerts_is_none():
    assert bike.warning_level([]) is None


# --- CAP language ----------------------------------------------------------

_CAP_XML = """<feed xmlns="http://www.w3.org/2005/Atom"><entry><content>
<alert xmlns="urn:oasis:names:tc:emergency:cap:1.2">
 <info><language>fi-FI</language><event>Tuulivaroitus</event><severity>Moderate</severity></info>
 <info><language>en-GB</language><event>Wind warning</event><severity>Moderate</severity></info>
</alert></content></entry></feed>"""


def test_cap_picks_the_requested_language():
    assert warn.parse_cap(_CAP_XML, "en-GB")[0]["event"] == "Wind warning"


def test_cap_without_a_language_keeps_the_old_first_block_behaviour():
    assert warn.parse_cap(_CAP_XML)[0]["event"] == "Tuulivaroitus"
