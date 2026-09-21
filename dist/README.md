# Releases and hand-off builds

**Everything shippable lives here.** Not the Desktop, not a temp folder — one
place, so there is never a question of which file is the current one.

Named by version, so the same rule applies as to the build outputs in
`watch/bin/`: if you cannot tell two files apart by their names, one of them
will eventually be sideloaded by mistake.

| File | What |
|---|---|
| `FIWeatherWatch-v0.1.6.prg` | sideload — copy to `GARMIN/APPS/` |
| `FIWeatherWatch-v0.1.6-settings.json` | its settings — copy to `GARMIN/APPS/SETTINGS/` |
| `FIWeatherWatch-v0.1.6.iq` | store upload (Beta release) |
| `FIWeatherWatch-v0.1.6-WHATS-NEW.txt` | what changed and what to test |
| `FIWeatherWatch-Peter-v0.1.4.zip` | Peter's tester build — Karjaa / Hanko Russarö / Suomenlahti |

`.prg` files are built for `fenix847mm`, which covers quatix 8 — the two are
API-identical and quatix has no separate simulator profile.

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

Check the defaults actually landed before sending — the generated
`*-settings.json` lists them, and the `.prg` contains the place name as a
string. A build whose defaults silently stayed at Helsinki looks fine until the
tester opens it.
