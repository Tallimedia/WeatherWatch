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

# Fintraffic Digitraffic — the categorical road-condition layer FMI does not
# provide (FIRoadWeather/RESEARCH.md §5.2). No key; gzip is mandatory and the
# service 406s without it, and it rate-limits 60 requests/min per IP.
DIGITRAFFIC_BASE = os.getenv("DIGITRAFFIC_BASE", "https://tie.digitraffic.fi")

# Digitraffic asks callers to identify themselves and raises the allowance for
# those who do. Never put personal information here — Fintraffic say so
# explicitly.
DIGITRAFFIC_USER = os.getenv(
    "DIGITRAFFIC_USER", "FIRoadWeather/1.0 (+https://roadweather.tallimedia.com)"
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

# Road TTLs. Station observations move on a ten-minute cadence like any other
# observation; the section forecast is recomputed a few times an hour. The two
# metadata calls describe geography — station positions and road-section
# geometry — which changes a few times a year, so they are cached for hours to
# stay well inside Digitraffic's 60/min.
TTL_ROAD_OBS = int(os.getenv("TTL_ROAD_OBS", "300"))
TTL_ROAD_FORECAST = int(os.getenv("TTL_ROAD_FORECAST", "900"))
TTL_ROAD_GEOMETRY = int(os.getenv("TTL_ROAD_GEOMETRY", "21600"))

# Warnings. FMI reissue CAP alerts on a slow cadence and each one carries its
# own onset/expires, so a few minutes of staleness changes nothing. The
# Fintraffic message feed is 1.2 MB with no bbox parameter, so it is fetched
# once for the whole country and filtered per request — the TTL is what keeps
# that affordable inside the 60/min limit.
TTL_CAP = int(os.getenv("TTL_CAP", "300"))
TTL_TRAFFIC_MESSAGES = int(os.getenv("TTL_TRAFFIC_MESSAGES", "300"))

# The prototype charts site is the internal research tool — date scrubbing, raw
# JSON, questions like "does this parameter earn its place" — and stays LAN-only
# (RESEARCH.md §19). Default off.
ENABLE_CHARTS = _flag("ENABLE_CHARTS", False)

# The public weather page: what the watch shows, live, for people arriving from
# the Connect IQ store listing. Distinct from the charts site, not the same page
# with a flag. Default off so a bare deploy exposes nothing but the API.
ENABLE_PUBLIC = _flag("ENABLE_PUBLIC", False)

# Defaults match the app's shipped settings: Helsinki / Harmaja / Suomenlinna.
# Connect IQ store URL. Unset until the app is published — the page then says
# "coming to the store" rather than offering a link that goes nowhere.
STORE_URL = os.getenv("STORE_URL", "")

# Where the live weather data lives. It is served from this same container but
# only under its own hostname, so the app page links out to it rather than
# carrying a second copy.
WEATHER_URL = os.getenv("WEATHER_URL", "https://weather.tallimedia.com")

# The app site, for the weather page to link back to.
APP_URL = os.getenv("APP_URL", "https://weatherapp.tallimedia.com")

DEFAULT_PLACE = os.getenv("DEFAULT_PLACE", "Helsinki")
DEFAULT_SEA_FMISID = int(os.getenv("DEFAULT_SEA_FMISID", "100996"))  # Helsinki Harmaja
