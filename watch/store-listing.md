# Connect IQ Store listing copy — v1.0.0

Paste-ready text for <https://apps-developer.garmin.com>. Keep in sync with
`../CHANGELOG.md`.

The beta (v0.1.x) is unlisted and needs no copy. This is the copy that shipped as the
public v1.0.0 entry.

**Live on the Connect IQ Store since 2026-09-22** (submitted 2026-09-21, approved in
a day). Public listing:
<https://apps.garmin.com/apps/172c2042-7cc8-4125-a0f6-9ba109be3a8a> — the locale-less
form, so the store follows the viewer's own language rather than pinning fi-FI. That URL
is set as `STORE_URL` in the backend `.env` on public-vm, which is what turns the site's
button into "Get it on Connect IQ".

Dashboard (sign-in only, not a public link):
<https://apps-developer.garmin.com/fi-FI/apps/172c2042-7cc8-4125-a0f6-9ba109be3a8a>.

---

## Short description (≤50 chars)

```
Finnish weather, wind and waves, land and sea
```
(45)

Alternatives, all within 50:

- `FMI weather on your wrist — land and sea` (40)
- `Finnish forecasts, marine wind and live waves` (45)
- `Weather and sea state from Finland's own data` (45)

---

## Full description (≤4000 chars)

```
Finnish weather, land and sea.

FIWeatherWatch shows what the Finnish Meteorological Institute's own instruments
are reporting right now — not a global model's guess at Finland. Forecasts for
your town, wind and gusts from the coastal marine stations, and live wave height
from FMI's wave buoys.

LAND
Current temperature and wind from the nearest reporting station, with the station
named and its distance shown, so you know where the number came from. A
six-hourly forecast strip covers the rest of the day.

SEA
Wind, gusts and direction from any of 40 Finnish coastal stations — Harmaja,
Utö, Kalbådagrund, Mäkiluoto, Bågaskär, Märket and the rest — plus 14 inland
lake stations, because a chart of Saimaa is a merikartta too. Air temperature at
the station as well.

WAVES
Significant wave height, period, direction and sea water temperature from FMI's
wave buoys. The buoys are lifted out of the water roughly December to April; when
none is reporting, the app says so and falls back to model output, clearly
labelled as modelled rather than measured.

YOUR OWN LIMITS
Set the wind, gust and wave heights that matter to you, and a reading is
highlighted when it crosses one. The defaults are sensible; the point is that
they are yours. A cold and a hot temperature limit work the same way.

GLANCE
Pick any two values for the glance carousel — land temperature, land wind, sea
wind and gust, wave height, water temperature — and read them without opening
the app.

EVERY VALUE IS TIMESTAMPED
Stations report at different rates. Harmaja republishes wind every minute; most
stations manage every ten; a wave buoy reports height every half hour but water
temperature every five minutes. So each reading shows its own age rather than
pretending they were all taken together. If the phone is out of range, the last
reading stays on screen and says that it is the last reading.

LANGUAGES
Finnish, Swedish and English, following your watch's own language setting. No
setting to find.

UNITS
Wind in m/s, knots or Beaufort. Distance in kilometres or nautical miles.

COVERAGE
Finland only. The data comes from the Finnish Meteorological Institute's own
network, so the places, coastal stations and wave buoys are Finnish ones. If you
sail the Gulf of Finland, the Archipelago Sea, the Bothnian Sea or the Åland
waters, that is exactly the area this covers — but it will not show you the
weather at home in Stockholm, Tallinn or Kiel.

WHAT IT NEEDS
A phone connection or WiFi. No account, no sign-in, nothing to configure beyond
your own place and station. Settings are edited in Garmin Connect Mobile.

Weather data: Finnish Meteorological Institute, licensed CC BY 4.0.
FIWeatherWatch is an independent project, not affiliated with or endorsed by the
Finnish Meteorological Institute or Garmin.
```

---

## What's new — v1.0.0

```
First public release.

• Land forecast and current conditions from the nearest reporting station
• Marine wind and gusts from 40 coastal and 14 inland lake stations
• Wave height, period, direction and water temperature from FMI wave buoys
• Your own wind, gust, wave and temperature limits
• Configurable glance with two values of your choosing
• Finnish, Swedish and English, following the watch's language
• Wind in m/s, knots or Beaufort; distance in km or nautical miles
```

---

## Availability

Nordics, Baltics and Germany: Finland, Sweden, Norway, Denmark, Iceland, Estonia,
Latvia, Lithuania, Germany.

**Availability and coverage are different things, and the listing has to say so.**
The restriction is about who can install the app; the data is Finnish wherever
you are. A German buyer cruising the Baltic is exactly the intended reader — a
German buyer wanting German weather is not, and would leave a one-star review
saying the app does not work. The COVERAGE paragraph above exists for that
reason and should not be cut for length.

## Artwork

`store/make_store_art.py` renders both images:

- `store/hero-1440x720.png`
- `store/cover-500x500.png`

The watch screen in both is a **real capture** pasted into the SDK's device skin,
so the artwork cannot drift from the product. Re-run the script after any UI
change, and retake `Screenshots/pg1.png` first.

**Before the v1.0.0 upload**, retake that capture from a v1.0.0 build — the
current one shows `v0.1.4` in the footer, which would ship a beta version number
into the store artwork.

---

## Screenshots

From `Screenshots/framed/` — framed in the device, already under the store's
300 kB limit:

| File | Shows |
|---|---|
| `pg1.png` | Land — temperature, wind, forecast strip |
| `pg2.png` | Sea — station wind, gust, direction |
| `pg3.png` | Waves — height, period, direction, water temperature |
| `glance.png` | Glance carousel |

An About-page capture is still missing and should be added: it carries the FMI
attribution.
