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

## Listing language

The Connect IQ store takes a **separate description per language**, and the app
already declares `eng`, `fin` and `swe`. **Finnish is the primary listing** — the data is
Finland-only and so is most of the audience. English is the fallback everyone else sees.

The dashboard offers **a name and a description, nothing else** — no short-description
field, no feature bullets, no subtitle. Everything the listing says has to live in those
two boxes.

Rewritten 2026-09-23, shorter: the v1.0.0 launch text ran 2 795 characters and read like
documentation. These run 1583 (fi) and 1788 (en). Nothing load-bearing was cut —
COVERAGE and the CC BY attribution are both still here, for the reasons noted below.

---

## App name

**Decided 2026-09-23.** The name is set per language, same as the description, and the
**limit is 50 characters** (confirmed in the dashboard). Both names below are 47, so there
are three characters of headroom and no room for a fourth word.

**Finnish:**

```
Suomen sää, tuuli ja aallot — maalla ja vesillä
```
(47)

**English:**

```
Finnish weather, wind and waves, land and water
```
(47)

**Why these.** The dashboard has two fields only — a name and a description — so the name
is the whole short pitch, and it is what store search matches on. A bare product name
would waste it. Both forms say *on the water* rather than *at sea*: `vesillä` covers sea
and lakes alike, `merellä` does not, and 14 of the 54 stations are on lakes, so the
distinction is real rather than stylistic. "land and water" carries the same sense in
English.

**This replaces the v1.0.0 name** `Finnish weather for land and sea with waves`, which was
English-only and excluded the lake stations. Changing it is a dashboard edit, not a new
build.

**The launcher name on the watch is a different string and does not change.**
`AppName` is `FIWeatherWatch` in all three language packs
(`watch/resources*/strings/strings.xml`), which is what appears on the device, in the
glance carousel and in settings. The store name and the on-device name are allowed to
differ and here they should: the store name sells, the launcher label identifies. Every
other surface — the site, the repo, the artwork, the About page — says FIWeatherWatch, so
that stays the product name.

---

## Description — Finnish (1583 chars)

Nico's wording, 2026-09-23. Two changes from the first draft: the *"ei globaalin mallin
arvausta Suomesta"* clause is gone, and `Garmin IQ Connect Mobilessa` was corrected to
`Connect IQ -sovelluksessa`. Connect IQ is both the platform and the name of the
companion app, so the app reference is right — only the word order was wrong
(`Garmin IQ Connect` → `Connect IQ`), and a transposed product name reads as an error to
exactly the Finnish audience this listing is for. The English body uses "the Connect IQ
app" to match.

```
Suomen sää, maalla ja merellä.

FIWeatherWatch näyttää sen, mitä Ilmatieteen laitoksen omat mittarit raportoivat juuri nyt.

MAA
Lämpötila ja tuuli lähimmältä havaintoasemalta, asema ja sen etäisyys näkyvissä. Ennuste kuuden tunnin välein loppupäivälle.

MERI
Tuuli, puuskat ja suunta 40 rannikkoasemalta ja 14 sisävesiasemalta — Harmajasta Märketiin, Saimaalta Näsijärvelle.

AALLOT
Merkitsevä aallonkorkeus, jakso, suunta ja veden lämpötila Ilmatieteen laitoksen aaltopoijuilta. Poijut nostetaan talveksi pois vedestä; silloin sovellus kertoo sen ja näyttää mallidataa selvästi merkittynä.

OMAT RAJASI
Aseta tuulen, puuskan ja aallonkorkeuden rajat, niin lukema korostuu kun raja ylittyy.

VILKAISU
Valitse kaksi arvoa vilkaisunäkymään ja lue ne avaamatta sovellusta.

Jokaisen lukeman ikä näkyy erikseen — asemat raportoivat eri tahtiin, eikä sovellus teeskentele muuta. Jos puhelin ei ole kantamalla, viimeisin lukema jää näkyviin ja kertoo olevansa viimeisin.

Suomi, ruotsi ja englanti kellon oman kieliasetuksen mukaan. Tuuli m/s, solmuina tai boforeina; etäisyys kilometreinä tai meripeninkulmina.

KATTAVUUS
Vain Suomi. Data tulee Ilmatieteen laitoksen omasta havaintoverkosta, joten paikat, rannikkoasemat ja poijut ovat suomalaisia. Suomenlahti, Saaristomeri, Selkämeri ja Ahvenanmaan vedet kyllä — Tukholman tai Tallinnan sää ei.

Vaatii puhelinyhteyden tai WiFin. Ei tiliä eikä kirjautumista. Asetukset Connect IQ -sovelluksessa.

Säädata: Ilmatieteen laitos, CC BY 4.0 -lisenssillä. FIWeatherWatch on itsenäinen projekti, ei Ilmatieteen laitoksen eikä Garminin tukema.
```

---

## Description — English (1788 chars)

```
Finnish weather, land and sea.

FIWeatherWatch shows what the Finnish Meteorological Institute's own instruments are reporting right now — not a global model's guess at Finland.

LAND
Temperature and wind from the nearest reporting station, with the station and its distance shown. A six-hourly forecast covers the rest of the day.

SEA
Wind, gusts and direction from 40 coastal and 14 inland lake stations — Harmaja to Märket, Saimaa to Näsijärvi.

WAVES
Significant wave height, period, direction and water temperature from FMI's wave buoys. The buoys are lifted out for the winter; when none is reporting the app says so and falls back to model output, clearly labelled.

YOUR OWN LIMITS
Set the wind, gust and wave heights that matter to you, and a reading is highlighted when it crosses one.

GLANCE
Pick two values for the glance carousel and read them without opening the app.

Every reading shows its own age — stations report at different rates and the app does not pretend otherwise. If the phone is out of range, the last reading stays on screen and says that it is the last one.

Finnish, Swedish and English, following your watch's language. Wind in m/s, knots or Beaufort; distance in kilometres or nautical miles.

COVERAGE
Finland only. The data comes from FMI's own observation network, so the places, coastal stations and buoys are Finnish. The Gulf of Finland, the Archipelago Sea, the Bothnian Sea and the Åland waters yes — the weather at home in Stockholm or Tallinn no.

Needs a phone connection or WiFi. No account, no sign-in. Settings are edited in the Connect IQ app.

Weather data: Finnish Meteorological Institute, licensed CC BY 4.0. FIWeatherWatch is an independent project, not affiliated with or endorsed by the Finnish Meteorological Institute or Garmin.
```

**Do not cut COVERAGE for length.** Availability and coverage are different claims and the
store only lets you set the first. The app sells in nine countries and shows Finnish data
only; a German or Swedish buyer who discovers that after installing leaves an accurate
one-star review. Those four lines are the cheapest review insurance in the listing.

**Do not cut the attribution line.** CC BY 4.0 requires it, and it is the one legal
obligation the listing carries.

---

## Prepared: the "what differs by watch" paragraph

**Not for use yet.** This goes in *with* the release that adds the monochrome Instinct
family, never before — the app does not support those devices today and the paragraph
would be a false claim (same rule as the Syke copy, `SYKE-RESEARCH.md` §12).

**Why it is needed.** The store serves **one description per language to every device**;
there is no per-device text. A fenix owner and an Instinct owner read the same words, so
the words have to be true on a colour round screen and on a 1-bit 176×176 semi-octagon.
The rest of the description already is — *korostuu* / *highlighted* never says "orange" —
but a buyer with an Instinct still deserves to know before installing what their screen
will actually do.

**What genuinely differs:** only how a reading past your limit is emphasised. Same data,
same four pages, same stations, same settings, same three languages.

**Finnish** — insert after the OMAT RAJASI block:

```
NÄYTÖT
Sama data ja samat sivut kaikilla tuetuilla kelloilla. Mustavalkonäyttöisissä
malleissa (Instinct, Descent G1) rajan ylittävä lukema korostuu käänteisenä
värin sijaan. Muuta eroa ei ole.
```

**English** — insert after the YOUR OWN LIMITS block:

```
ACROSS WATCHES
The same data and the same pages on every supported watch. On black-and-white
models (Instinct, Descent G1) a reading past your limit is highlighted in
inverse rather than in colour. Nothing else differs.
```

**Screenshots matter more than this paragraph.** All four current captures are colour
fenix screens. Ship at least one monochrome capture in the same release, so nobody buys
on the strength of a picture their watch cannot draw. Confirm in the dashboard whether
screenshots can be attached **per device** or are a single shared set — that decides
whether Instinct gets its own or the shared set has to include one.

---

## What's new — v1.0.0

**Finnish:**

```
Ensimmäinen julkinen versio.

• Maasää ja ennuste lähimmältä havaintoasemalta
• Merituuli ja puuskat 40 rannikko- ja 14 sisävesiasemalta
• Aallonkorkeus, jakso, suunta ja veden lämpötila poijuilta
• Omat tuuli-, puuska-, aalto- ja lämpötilarajat
• Vilkaisunäkymä kahdella itse valitulla arvolla
• Suomi, ruotsi ja englanti kellon kieliasetuksen mukaan
• Tuuli m/s, solmuina tai boforeina; etäisyys km tai mpk
```

**English:**

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

**One set per app, not per device, and the count is capped** — every watch sees the same
images, so each slot has to earn its place. From `Screenshots/framed/`, framed in the
device skin, already under the store's 300 kB limit:

| File | Shows |
|---|---|
| `pg1.png` | Land — temperature, wind, forecast strip |
| `pg2.png` | Sea — station wind, gust, direction |
| `pg3.png` | Waves — height, period, direction, water temperature |
| `glance.png` | Glance carousel |

### Priority order, so the cap decides itself

Take the top N for whatever N the dashboard allows. Colour first — it is the large
majority of supported devices and the gallery preview shows image one.

1. **`pg2.png` Sea** — the differentiator. Nobody else serves FMI marine stations
2. **`pg3.png` Waves** — the unique data, live buoys
3. **`pg1.png` Land** — the everyday page, and the one that says "this is a weather app"
4. **`glance.png` Glance** — convenience, and the feature most users will actually live in
5. **Monochrome capture** — *add with the Instinct release, not before.* See below
6. **About page** — lowest priority, and **not** an attribution requirement: CC BY is
   satisfied by the description line *"Säädata: Ilmatieteen laitos, CC BY 4.0"*, which is
   text and already there. Drop this before dropping anything above it

### The monochrome slot

When the Instinct family is added, one image has to show a black-and-white screen, or
buyers on eight devices choose on the strength of a picture their watch cannot draw.

**Make it the Sea or Waves page with a value over the user's limit**, so the one capture
does two jobs: it shows the monochrome rendering honestly, and it demonstrates the
inverse-video highlight that replaces colour there. A mono screenshot of an unremarkable
reading wastes the slot.

Keep it late in the order — a colour image should stay first for the gallery preview.

### Open

An About-page capture has never been taken. Given the priority above it is optional, but
`Screenshots/` should still hold one for the site and for documentation.
