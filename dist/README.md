# Releases

**Everything shippable lives here.** Not the Desktop, not a temp folder — one
place, so there is never a question of which file is current.

| File | What |
|---|---|
| `FIWeatherWatch-v1.0.0.iq` | the store upload |
| `FIWeatherWatch-v1.0.0.prg` | sideload — copy to `GARMIN/APPS/` |
| `FIWeatherWatch-v1.0.0-settings.json` | its settings — copy to `GARMIN/APPS/SETTINGS/` |
| `hero-1440x720.png` | store banner |
| `cover-500x500.png` | store tile |
| `screenshots/` | the store gallery, framed in the device |
| `FIWeatherWatch-Peter-v0.1.4.zip` | an old tester build, kept for reference |

The listing copy is in [`../watch/store-listing.md`](../watch/store-listing.md).

`.prg` files are built for `fenix847mm`, which covers quatix 8 — the two are
API-identical and quatix has no separate simulator profile.

## Screenshots

Captured from the simulator, framed by `Screenshots/frame.py` in whichever
device they came from, and kept under the store's 300 kB limit.

They carry no version number: the build number lives on the About page only, so
the artwork does not expire with each release. That was not true before v1.0.0.

## Per-tester builds

Defaults are compiled in, so a build for someone else means editing
`watch/resources/settings/properties.xml`, building, and **putting it back**:

```bash
cp watch/resources/settings/properties.xml /tmp/properties.orig.xml
# edit landPlace / seaStation / seaBuoy
cd watch && monkeyc -d fenix847mm -o bin/fiweatherwatch-<ver>-<who>-fenix847mm.prg \
  -f monkey.jungle -y ~/.garmin-ciq/developer_key.der -w
cp /tmp/properties.orig.xml resources/settings/properties.xml
```

Check the defaults landed before sending — the generated `*-settings.json` lists
them. A build whose defaults silently stayed at Helsinki looks fine until the
tester opens it.
