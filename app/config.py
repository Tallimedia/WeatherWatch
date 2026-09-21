"""Runtime configuration, all overridable by environment variable."""
import os


def _flag(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


# FMI endpoints. No API key exists or is required (see RESEARCH.md §2).
FMI_TIMESERIES = os.getenv("FMI_TIMESERIES", "https://opendata.fmi.fi/timeseries")
FMI_WFS = os.getenv("FMI_WFS", "https://opendata.fmi.fi/wfs")

HTTP_TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "20"))

# FMI publishes no rate limits and asks for no key, so identifying the client is
# the only courtesy available: an operator who sees a problem has somewhere to
# look rather than an anonymous Python default.
USER_AGENT = os.getenv(
    "USER_AGENT", "FIWeatherWatch/0.1 (+https://weatherapp.tallimedia.com)"
)

# A place name is a gazetteer lookup, not free text. Anything longer is not a
# Finnish place and only serves to bloat a cache key.
MAX_PLACE_LEN = int(os.getenv("MAX_PLACE_LEN", "64"))

# Cache TTLs in seconds. FMI publishes no rate limits, so we cache to stay well
# inside fair use (RESEARCH.md §13). Forecasts refresh hourly at source, WAM
# every six hours, observations every ten minutes.
TTL_FORECAST = int(os.getenv("TTL_FORECAST", "900"))
TTL_OBSERVATIONS = int(os.getenv("TTL_OBSERVATIONS", "300"))
TTL_MARINE = int(os.getenv("TTL_MARINE", "600"))
# A name FMI does not know will not start being known in the next few minutes,
# and each attempt costs four upstream calls.
TTL_UNKNOWN_PLACE = int(os.getenv("TTL_UNKNOWN_PLACE", "600"))

# The prototype charts site is the internal research tool — date scrubbing, raw
# JSON, questions like "does this parameter earn its place" — and stays LAN-only
# (RESEARCH.md §19). Default off.
ENABLE_CHARTS = _flag("ENABLE_CHARTS", False)

# The public weather page: what the watch shows, live, for people arriving from
# the Connect IQ store listing. Distinct from the charts site, not the same page
# with a flag. Default off so a bare deploy exposes nothing but the API.
ENABLE_PUBLIC = _flag("ENABLE_PUBLIC", False)

# Defaults match the app's shipped settings: Helsinki / Harmaja / Suomenlinna.
# How far an automatically chosen wave buoy may sit from the station. Every
# buoy is 100+ km from Hanko, so this cannot be tight; but without any cap an
# inland lake gets handed a Baltic buoy and shown it as local sea state.
BUOY_MAX_KM = float(os.getenv("BUOY_MAX_KM", "150"))

DEFAULT_PLACE = os.getenv("DEFAULT_PLACE", "Helsinki")
DEFAULT_SEA_FMISID = int(os.getenv("DEFAULT_SEA_FMISID", "100996"))  # Helsinki Harmaja
