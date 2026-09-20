import math

from app.geo import bearing_deg, compass_8, haversine_km


def test_haversine_matches_known_distances():
    # Harmaja -> Suomenlinna buoy, verified against FMI positions (RESEARCH.md §4).
    assert haversine_km(60.1051, 24.9754, 60.12333, 24.97283) == round_to(2.0)
    # Harmaja -> Suomenlahti buoy, the open-sea one 21 km south.
    assert haversine_km(60.1051, 24.9754, 59.965, 25.235) == round_to(21.2)


def round_to(expected: float, tol: float = 0.1):
    class Approx:
        def __eq__(self, other):
            return abs(other - expected) <= tol

        def __repr__(self):
            return f"~{expected}"

    return Approx()


def test_haversine_is_symmetric_and_zero_for_same_point():
    assert haversine_km(60.0, 24.0, 60.0, 24.0) == 0
    assert math.isclose(
        haversine_km(60.0, 24.0, 61.0, 25.0), haversine_km(61.0, 25.0, 60.0, 24.0)
    )


def test_compass_wraps_correctly_at_north():
    assert compass_8(0) == "N"
    assert compass_8(359) == "N"
    assert compass_8(23) == "NE"
    assert compass_8(180) == "S"
    assert compass_8(225) == "SW"


def test_bearing_points_the_right_way():
    assert 170 < bearing_deg(61.0, 24.0, 60.0, 24.0) < 190  # due south
    assert bearing_deg(60.0, 24.0, 60.0, 25.0) == round_to(90.0, tol=1.0)  # due east
