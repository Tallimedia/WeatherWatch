"""Road endpoint shaping and the derived ice risk.

The ice logic is the reason these exist. It cannot be exercised against live
data for most of the year — every reading in September says "well above
freezing" — so the winter branches are only ever covered here.
"""

from app.main import _latest_road, _shape_section
from app.road import ice_risk, nearest_section, nearest_station, sensor_map


# --------------------------------------------------------------------------
# Ice risk
# --------------------------------------------------------------------------

def test_air_above_zero_does_not_clear_a_freezing_road():
    """The whole reason the app exists: air temperature is the wrong number.

    The road radiates to the sky and runs colder than the air, so +2 in the
    cabin can sit above a surface at -1.
    """
    risk = ice_risk(road_temp_c=-1.0, dew_point_c=-6.0, air_temp_c=2.0)
    assert risk["level"] == "moderate"
    assert "freezing" in risk["reason"]


def test_below_freezing_and_at_the_dew_point_is_the_dangerous_case():
    """Frost forms on a road that looks dry, which is what makes it dangerous."""
    risk = ice_risk(road_temp_c=-2.0, dew_point_c=-1.5, air_temp_c=-1.0)
    assert risk["level"] == "high"
    assert "frost" in risk["reason"] or "black ice" in risk["reason"]


def test_near_freezing_and_damp_is_worse_than_near_freezing_and_dry():
    damp = ice_risk(road_temp_c=1.0, dew_point_c=1.5, air_temp_c=2.0)
    dry = ice_risk(road_temp_c=1.0, dew_point_c=-8.0, air_temp_c=2.0)
    assert damp["level"] == "moderate"
    assert dry["level"] == "low"


def test_missing_surface_temperature_is_unknown_not_safe():
    """A station that did not report must not read as 'no risk'.

    Silently downgrading absent data to reassurance is the one failure mode
    that could actually hurt someone.
    """
    risk = ice_risk(road_temp_c=None, dew_point_c=-4.0, air_temp_c=-3.0)
    assert risk["level"] == "unknown"
    assert risk["level"] != "none"


def test_warm_road_is_clear():
    assert ice_risk(road_temp_c=12.0, dew_point_c=9.0, air_temp_c=11.0)["level"] == "none"


def test_dew_point_alone_cannot_raise_risk_on_a_warm_road():
    """Condensation on a 12 °C road is dew, not ice."""
    assert ice_risk(road_temp_c=12.0, dew_point_c=13.0, air_temp_c=14.0)["level"] == "none"


# --------------------------------------------------------------------------
# FMI row collapsing
# --------------------------------------------------------------------------

def test_reading_comes_from_one_station_not_a_composite():
    """`numberofstations` interleaves stations, and mixing them invents a place.

    Without filtering to the nearest first, the road temperature from a station
    2 km away would be merged with a dew point from one 40 km away and served
    as a single reading.
    """
    rows = [
        {"epochtime": 100, "distance": 2.0, "stationname": "near",
         "roadtemperature": -1.0, "dewpoint": None},
        {"epochtime": 100, "distance": 40.0, "stationname": "far",
         "roadtemperature": 5.0, "dewpoint": 4.0},
    ]
    out = _latest_road(rows)
    assert out["station"] == "near"
    assert out["road_temp_c"] == -1.0
    assert out["dew_point_c"] is None, "must not borrow the distant station's dew point"


def test_negative_snow_depth_means_no_snow():
    """FMI reports -1 for 'no snow'. Passed through, the client draws a
    negative bar."""
    rows = [{"epochtime": 100, "distance": 1.0, "stationname": "s", "snowdepth": -1.0}]
    assert _latest_road(rows)["snow_depth_cm"] == 0


def test_no_rows_is_empty_not_an_exception():
    assert _latest_road([]) == {}


# --------------------------------------------------------------------------
# Digitraffic shaping
# --------------------------------------------------------------------------

def test_nearest_station_picks_the_closest_by_great_circle():
    stations = {"features": [
        {"geometry": {"coordinates": [25.50, 60.20]},
         "properties": {"id": 2, "name": "far"}},
        {"geometry": {"coordinates": [24.95, 60.17]},
         "properties": {"id": 1, "name": "near"}},
    ]}
    assert nearest_station(stations, 60.17, 24.94)["name"] == "near"


def test_digitraffic_test_rigs_are_not_offered_as_the_nearest_sensor():
    """Ten of Digitraffic's 528 stations are their own test rigs.

    Fintraffic flag them nowhere in the metadata — `collectionStatus` reads
    `GATHERING` exactly like a real station — so the name is the only signal.
    They sit in Lapland, where real coverage is thinnest, and at Utsjoki the
    test rig is genuinely the closest thing there is.
    """
    stations = {"features": [
        {"geometry": {"coordinates": [27.03, 69.90]},
         "properties": {"id": 1, "name": "TEST_st970_Utsjoki_Nuvvus_Lumi",
                        "collectionStatus": "GATHERING"}},
        {"geometry": {"coordinates": [28.00, 70.08]},
         "properties": {"id": 2, "name": "st970_Utsjoki_Nuorgam",
                        "collectionStatus": "GATHERING"}},
    ]}
    assert nearest_station(stations, 69.908, 27.029)["name"] == "st970_Utsjoki_Nuorgam"


def test_a_withdrawn_station_is_not_the_nearest_sensor():
    """Coordinates outlive service. A station Fintraffic have pulled is not a
    reading, however close it still plots."""
    stations = {"features": [
        {"geometry": {"coordinates": [24.94, 60.17]},
         "properties": {"id": 1, "name": "near_but_gone",
                        "collectionStatus": "REMOVED_TEMPORARILY"}},
        {"geometry": {"coordinates": [25.50, 60.20]},
         "properties": {"id": 2, "name": "further_but_live",
                        "collectionStatus": "GATHERING"}},
    ]}
    assert nearest_station(stations, 60.17, 24.94)["name"] == "further_but_live"


def test_nearest_section_measures_to_the_line_not_its_first_point():
    """Sections are LineStrings. Ranking on the first vertex alone picks the
    wrong road whenever a long section starts far away and passes close by."""
    sections = {"features": [
        {"geometry": {"type": "LineString",
                      "coordinates": [[25.90, 60.90, 0], [24.941, 60.168, 0]]},
         "properties": {"id": "passes-close", "description": "Kt 51"}},
        {"geometry": {"type": "LineString",
                      "coordinates": [[25.10, 60.30, 0], [25.20, 60.40, 0]]},
         "properties": {"id": "stays-away", "description": "Vt 4"}},
    ]}
    assert nearest_section(sections, 60.167, 24.940)["id"] == "passes-close"


def test_section_forecasts_are_matched_by_id_not_position():
    """The bbox returns every section in the box, in no guaranteed order."""
    section = {"id": "B", "description": "Vt 9", "road_number": 9, "distance_km": 0.4}
    forecasts = {"forecastSections": [
        {"id": "A", "forecasts": [{"forecastName": "0h", "roadTemperature": 99.0}]},
        {"id": "B", "forecasts": [{"forecastName": "0h", "roadTemperature": -2.0,
                                   "overallRoadCondition": "POOR_CONDITION",
                                   "reliability": "SUCCESSFUL",
                                   "forecastConditionReason": {"roadCondition": "ICY"}}]},
    ]}
    out = _shape_section(section, forecasts)
    assert out["outlook"][0]["road_temp_c"] == -2.0
    assert out["outlook"][0]["surface"] == "ICY"
    assert out["outlook"][0]["reliability"] == "SUCCESSFUL"


def test_section_with_no_matching_forecast_is_none_not_a_half_answer():
    assert _shape_section({"id": "X"}, {"forecastSections": []}) is None


def test_sensor_map_keeps_the_english_description():
    """`KELI_1` is a bare number; the description is what makes it usable."""
    data = {"sensorValues": [
        {"name": "KELI_1", "value": 1.0, "unit": "***", "sensorValueDescriptionEn": "Dry"},
    ]}
    assert sensor_map(data)["KELI_1"]["description"] == "Dry"


# --------------------------------------------------------------------------
# Access-log redaction
# --------------------------------------------------------------------------

def test_access_log_does_not_record_caller_coordinates():
    """Uvicorn logs the request line verbatim, which was building a passive
    location history the privacy policy says does not exist."""
    import logging

    from app.main import _RedactCoordinates

    record = logging.LogRecord(
        "uvicorn.access", logging.INFO, __file__, 1, '%s - "%s %s HTTP/%s" %d',
        ("127.0.0.1:1", "GET", "/v1/road?lat=60.1699&lon=24.9384", "1.1", 200), None,
    )
    _RedactCoordinates().filter(record)
    line = record.args[2]
    assert "60.1699" not in line and "24.9384" not in line
    assert line == "/v1/road?lat=<redacted>&lon=<redacted>"


def test_redaction_keeps_the_place_name_for_debugging():
    """A gazetteer name is coarse, and the 404 path is undebuggable without it."""
    import logging

    from app.main import _RedactCoordinates

    record = logging.LogRecord(
        "uvicorn.access", logging.INFO, __file__, 1, "%s %s %s %s %d",
        ("127.0.0.1:1", "GET", "/v1/observations?place=Espoo", "1.1", 200), None,
    )
    _RedactCoordinates().filter(record)
    assert record.args[2] == "/v1/observations?place=Espoo"


def test_fmi_road_rows_drop_the_same_test_rigs():
    """FMI's `producer=road` mirrors Fintraffic's station list, test rigs
    included — and the two sources are selected independently, so filtering
    only Digitraffic left the two halves of one reading naming different
    places: `station` said Nuorgam, `surface.station` said TEST_..._Nuvvus.
    """
    rows = [
        {"epochtime": 100, "distance": 33.5, "stationname": "TEST_st970_Utsjoki_Nuvvus_Lumi",
         "roadtemperature": -1.0},
        {"epochtime": 100, "distance": 40.1, "stationname": "st970_Utsjoki_Nuorgam",
         "roadtemperature": -2.0},
    ]
    out = _latest_road(rows)
    assert out["station"] == "st970_Utsjoki_Nuorgam"
    assert out["road_temp_c"] == -2.0


def test_only_test_rigs_nearby_is_empty_not_a_test_reading():
    assert _latest_road([{"epochtime": 1, "distance": 2.0,
                          "stationname": "TEST_TSA_1", "roadtemperature": 5.0}]) == {}


# --------------------------------------------------------------------------
# Warnings and road notices
# --------------------------------------------------------------------------

def test_a_road_work_is_measured_to_its_nearest_point_not_its_first():
    """Road works are MultiLineStrings — a stretch of road, not a dot.

    Ranking on the first coordinate would put a long roadwork that starts
    40 km away but passes the car below one that never comes close.
    """
    from app.warnings import shape_notice

    feature = {
        "geometry": {"type": "MultiLineString",
                     "coordinates": [[[25.90, 60.90], [24.9410, 60.1680]]]},
        "properties": {"situationType": "ROAD_WORK", "announcements": [{
            "title": "Tie 51. Tietyö.",
            "timeAndDuration": {"startTime": "x", "endTime": "y"},
            "locationDetails": {"roadAddressLocation": {"primaryPoint": {
                "municipality": "Helsinki", "roadName": "Länsiväylä",
                "roadAddress": {"road": 51}}}},
            "features": [{"name": "Nopeusrajoitus"}],
            "roadWorkPhases": [{"severity": "HIGH", "restrictions": [
                {"type": "SPEED_LIMIT", "restriction": {"quantity": 50, "unit": "km/h"}}]}],
        }]},
    }
    out = shape_notice(feature, 60.167, 24.940)
    assert out["distance_km"] < 1.0
    assert out["road"] == 51
    assert out["restrictions"][0] == {"type": "SPEED_LIMIT", "quantity": 50, "unit": "km/h"}


def test_notices_are_closest_first_and_bounded_by_radius():
    from app.warnings import notices_near

    def work(lon, lat, title):
        return {"geometry": {"type": "Point", "coordinates": [lon, lat]},
                "properties": {"situationType": "ROAD_WORK",
                               "announcements": [{"title": title}]}}

    msgs = {"features": [work(25.90, 60.90, "far"), work(24.945, 60.170, "near")]}
    out = notices_near(msgs, 60.167, 24.940, radius_km=25)
    assert [n["title"] for n in out] == ["near"], "the 90 km one must be dropped, not just ranked"


def test_a_sea_warning_does_not_reach_a_driver_on_land():
    """The whole reason alerts are matched by polygon rather than event name.

    This app is land and road only, and the CAP feed is mostly marine — six of
    six entries on 2026-09-22. Matching on names would need a keyword list that
    goes stale; the geometry already knows.
    """
    from app.warnings import alerts_at

    gulf = [(59.8, 24.0), (59.8, 26.0), (60.0, 26.0), (60.0, 24.0)]
    alerts = [{"event": "Yellow wind warning for sea area", "_rings": [gulf]}]
    assert alerts_at(alerts, 60.17, 24.94) == [], "Helsinki is not in the Gulf polygon"
    assert len(alerts_at(alerts, 59.9, 25.0)) == 1, "a point inside it must still match"


def test_cap_polygons_are_latitude_first():
    """CAP orders coordinates lat,lon — the opposite of GeoJSON. Reading them
    as lon,lat puts every Finnish warning in Somalia."""
    from app.warnings import parse_cap

    xml = """<feed xmlns="http://www.w3.org/2005/Atom">
      <entry><content><alert xmlns="urn:oasis:names:tc:emergency:cap:1.2">
        <info><event>Test</event><severity>Moderate</severity>
          <parameter><valueName>color</valueName><value>yellow</value></parameter>
          <area><areaDesc>Uusimaa</areaDesc>
            <polygon>60.0,24.0 60.0,25.0 61.0,25.0 61.0,24.0 60.0,24.0</polygon>
          </area>
        </info></alert></content></entry></feed>"""
    alert = parse_cap(xml)[0]
    assert alert["colour"] == "yellow"
    lats = [p[0] for p in alert["_rings"][0]]
    assert all(59 < v < 71 for v in lats), f"latitudes look like longitudes: {lats}"
