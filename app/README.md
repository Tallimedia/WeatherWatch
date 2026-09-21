# FIWeatherWatch — backend

Serves [Finnish Meteorological Institute](https://en.ilmatieteenlaitos.fi/open-data)
open data, reshaped for the FIWeatherWatch Garmin watch app.

Planning and research live in `RESEARCH.md`, which is owned by the `claude-docs`
repo rather than this one (see that repo's `CLAUDE.md`). Section references
below (§2, §4, …) point there.

## Why a backend at all

Monkey C has no XML parser, and Connect IQ starts failing somewhere around 32 kB
of response. FMI's documented interface is WFS/GML, wave-buoy observations exist
*only* there, and the warnings feed is 1.1 MB of CAP XML. This service turns all
of that into a few hundred bytes of JSON. It also gives the watch a TLS
certificate already proven to work on Garmin hardware. (§2, §10, §12)

## Endpoints

| Endpoint | Returns | Size |
|---|---|---|
| `GET /healthz` | liveness | — |
| `GET /v1/glance` | land temp + sea wind/gust | ~96 B |
| `GET /v1/observations` | nearest station, current conditions, provenance | ~300 B |
| `GET /v1/marine` | station wind + waves, with a `mode` field | ~510 B |
| `GET /v1/forecast` | land forecast, up to 10 days | ~0.8–1.4 kB |
| `GET /v1/marine-series` | 12 h of station wind + gust, for the web chart | ~1.8 kB |
| `GET /v1/stations` | marine stations and wave buoys, for the pickers | ~2 kB |

`/v1/marine-series` is for the public page, not the watch — a single current reading
cannot show whether the wind is rising or falling, and the watch cannot hold the
series anyway.

`/v1/marine` carries `mode` (`waves` or `model`) from day one. Sea ice adds a
third value in v1.5; shipping the field now keeps that a server change rather
than a redesign. (§16, §18)

## Running it

```bash
python3.12 -m venv .venv && .venv/bin/pip install -e ".[dev]"
.venv/bin/uvicorn app.main:app --reload --port 8791
.venv/bin/pytest -q
```

With Docker: `cp .env.example .env && docker compose up -d --build`

## Deployment

Production is `weatherapp.tallimedia.com`, on **public-vm** under
`~/public-services/weatherapp/`, behind the shared Traefik and Cloudflare tunnel. It
is not a git checkout — copy the tree up and rebuild:

```bash
tar --exclude='__pycache__' --exclude='.DS_Store' -czf - app Dockerfile pyproject.toml \
  | ssh public-vm-auto 'cd ~/public-services/weatherapp && tar -xzf -'
ssh public-vm-auto 'cd ~/public-services/weatherapp && docker compose build && docker compose up -d'
```

There is no `rsync` on that host. Tag `fiweatherwatch-backend:rollback` before
building so a revert is one command. `.env` there sets `ENABLE_PUBLIC=true` and
`ENABLE_CHARTS=false` — **the charts explorer must stay off in production.**

**Cloudflare caches assets for four hours and will hide a correct deploy.** Asset
URLs carry a hash of their own bytes (`site.js?v=<hash>`) and the HTML is served
`no-cache`, so a change always moves the URL. Verify against the live URL, never
against the file on the host — they have disagreed for hours while both were
"correct".

## Deployments

One repo, two targets (§19). Nothing is authored on a server.

| | Host | Charts | Reach |
|---|---|---|---|
| Prototype | `weather.int.kavaleff.com` | on | LAN only |
| Production | `<name>.tallimedia.com` (public-vm) | off | public |

## Gotchas this code exists to handle

Each of these was found by querying FMI and getting a plausible wrong answer:

- The bare `time` field is **local, not UTC** — 12:00 Helsinki is 09:00Z. We
  request `epochtime` everywhere instead.
- Values round to integers without `precision=double`.
- Gusts are `hourlymaximumgust` in forecasts but `windgust` in observations;
  asking for the wrong one returns nulls rather than an error.
- `bbox` is **silently ignored** by the wave stored query — it returns every
  buoy in Finland, so a naive read gives you one 517 km away. Buoys are filtered
  by distance in `app/geo.py`.
- `ModalWDi` is wave direction; `WHDD` is directional *spread*. Confusing them
  points the arrow about 180° wrong.
- Marine stations must be chosen by `fmisid`: `place=Bogskär` returns Mariehamn
  **airport**, `place=Isokari` returns Pori airport 18.6 km inland.

## Licence and attribution

FMI open data is **CC BY 4.0**, and attribution is required — every response
carries it, and the app must show it too.
