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

# Cache TTLs in seconds. FMI publishes no rate limits, so we cache to stay well
# inside fair use (RESEARCH.md §13). Forecasts refresh hourly at source, WAM
# every six hours, observations every ten minutes.
TTL_FORECAST = int(os.getenv("TTL_FORECAST", "900"))
TTL_OBSERVATIONS = int(os.getenv("TTL_OBSERVATIONS", "300"))
TTL_MARINE = int(os.getenv("TTL_MARINE", "600"))

# The prototype charts site is the internal research tool — date scrubbing, raw
# JSON, questions like "does this parameter earn its place" — and stays LAN-only
# (RESEARCH.md §19). Default off.
ENABLE_CHARTS = _flag("ENABLE_CHARTS", False)

# The public weather page: what the watch shows, live, for people arriving from
# the Connect IQ store listing. Distinct from the charts site, not the same page
# with a flag. Default off so a bare deploy exposes nothing but the API.
ENABLE_PUBLIC = _flag("ENABLE_PUBLIC", False)

# Defaults match the app's shipped settings: Helsinki / Harmaja / Suomenlinna.
DEFAULT_PLACE = os.getenv("DEFAULT_PLACE", "Helsinki")
DEFAULT_SEA_FMISID = int(os.getenv("DEFAULT_SEA_FMISID", "100996"))  # Helsinki Harmaja
