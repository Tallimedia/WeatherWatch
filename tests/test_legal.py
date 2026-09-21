"""The legal documents both apps are published with.

These are cheap tests for an expensive mistake: Play is given
`roadweather.tallimedia.com/privacy` as the car app's privacy policy URL, and
one container serves both apps. A renamed or missing file would quietly fall
back to the *other* app's policy, which is a store-policy problem rather than a
broken page — and it would look fine in a browser.
"""

import pytest

from app import legal

CAR = ("ROADWEATHER-PRIVACY", "ROADWEATHER-TERMS")
WATCH = ("PRIVACY", "TERMS")


@pytest.mark.parametrize("name", CAR + WATCH)
def test_document_renders(name):
    title, body = legal.document(name)
    assert title and body


@pytest.mark.parametrize("name", CAR)
def test_car_documents_are_the_car_app(name):
    title, _ = legal.document(name)
    assert "RoadWeather" in title
    assert "FIWeatherWatch" not in title


@pytest.mark.parametrize("name", WATCH)
def test_watch_documents_are_the_watch_app(name):
    title, _ = legal.document(name)
    assert "FIWeatherWatch" in title


def test_car_policy_describes_location_because_the_car_app_uses_it():
    """The watch app's policy says it has no location access. Serving that for
    the car app would be inaccurate, not merely mislabelled."""
    _, body = legal.document("ROADWEATHER-PRIVACY")
    assert "location" in body.lower()


@pytest.mark.parametrize("name", CAR)
def test_car_documents_carry_both_required_attributions(name):
    """CC BY obliges attribution, and Fintraffic specify their wording."""
    _, body = legal.document(name)
    assert "Finnish Meteorological Institute" in body
    assert "digitraffic.fi" in body
