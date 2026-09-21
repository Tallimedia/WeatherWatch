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


# --------------------------------------------------------------------------
# Asset cache busting
# --------------------------------------------------------------------------

def test_asset_fingerprint_covers_nested_static_files():
    """A one-level glob missed the car app's design preview.

    `app/roadweather/static/preview.js` sits two directories down, so
    `glob("*/*.js")` never saw it: its `?v=` stayed fixed while the bytes
    changed, and Cloudflare's four-hour cache kept serving the old file to the
    one page that exists to be re-reviewed after every change.
    """
    import hashlib
    from pathlib import Path

    here = Path(__file__).resolve().parent.parent / "app"
    preview = here / "roadweather" / "static" / "preview.js"
    assert preview.exists(), "the demo script moved; update this test"

    covered = sorted(here.rglob("*.js")) + sorted(here.rglob("*.css"))
    assert preview in covered

    def fingerprint(paths):
        digest = hashlib.sha256()
        for path in paths:
            digest.update(path.read_bytes())
        return digest.hexdigest()[:10]

    # Changing only the nested file must move the fingerprint.
    original = preview.read_bytes()
    before = fingerprint(covered)
    try:
        preview.write_bytes(original + b"\n// cache-bust probe\n")
        assert fingerprint(covered) != before
    finally:
        preview.write_bytes(original)
