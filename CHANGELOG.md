# Changelog

Watch app versions are what the Connect IQ store tracks and what the app draws in
its own footer. The store refuses a repeated version number, so **every upload gets
a new one** — including a rebuild of something never published, because otherwise
two different binaries share a number and a tester's report cannot be placed.

Design reasoning lives in `RESEARCH.md` (owned by the `claude-docs` repo).

## Watch app

### v0.1.4 — 2026-09-20
- **About page**, carrying the FMI attribution CC BY 4.0 requires in the app itself,
  plus the app name and build. Page count goes from 3 to 4; About is last in both
  page orders.
- Failures name themselves: 404 → place not found, 5xx or `BLE_REQUEST_TOO_LARGE` →
  service unavailable, anything else → no connection. Previously every non-200 read
  as "No connection", blaming the phone for a typo.
- A cached reading shown after a failed refresh says so instead of looking live.
- The three fetches chain from each other's callbacks rather than firing at once and
  overrunning Connect IQ's request queue; Select is debounced to 30 s.
- Page-order arrays hoisted out of `onUpdate`; six glance strings superseded by
  `Labels.mc` removed.

### v0.1.3 — 2026-09-20
- The version stopped colliding with the last-updated row. They sat at 0.855h and
  0.895h — about 18 px apart on a 454 px screen, against a font taller than that —
  so they drew on top of each other and the version, whose whole job is telling a
  tester which build they are on, was unreadable. Now one row: `12 min · v0.1.3`.

### v0.1.2 — 2026-09-20
- Glance captions to white. `LT_GRAY` measured fine against black in the simulator
  but the carousel dims the whole glance strip on AMOLED. The caption stays
  subordinate by font size instead.

### v0.1.1 — 2026-09-20
- **Finnish and Swedish strings.** The manifest had declared `eng`/`fin`/`swe` since
  the first build but both resource folders were empty, so every device fell back to
  English. No setting is involved — Connect IQ picks the folder from the device's
  system language.
- Glance captions from `DK_GRAY` to `LT_GRAY` (~2.9:1 → ~9:1 against black).
- Build outputs carry the version: `fiweatherwatch-<version>.iq`, and an optional
  device argument also builds `fiweatherwatch-<version>-<device>.prg`. An undated
  `.prg` left in `bin/` is indistinguishable from a current one, and sideloading a
  stale build looks exactly like a fix that did not work.

### v0.1.0 — 2026-09-20
- First beta for the Connect IQ store. Land, Sea and Waves pages, configurable
  glance, thresholds, Finnish marine stations and wave buoys.

## Backend

### 2026-09-20
- `/v1/marine-series` — mean and gust for the last 12 hours from the same station
  record `/v1/marine` reads, sampled every 20 minutes. For the public page; the
  watch cannot hold a series.
- Public page: hourly precipitation in the forecast strip, and the 12-hour wind
  trend chart.
- Cache bounded. Expired entries were dropped only when their own key was read
  again, and keys embed caller-supplied place names, so memory grew monotonically.
  Now swept on write, capped at 512.
- `/v1/glance` and `/v1/observations` no longer build the same cache key from
  separate code — the queries behind it had drifted, one resolving the place name to
  coordinates and the other asking by name.
- One `httpx.AsyncClient` for the process instead of one per request.
- Single-flight on cache misses; negative caching for unknown places (37 ms → 0.8 ms
  on repeat); `place` capped at 64 characters.
