# Hand-off builds

Tester builds, tracked here so they can be fetched from a machine that is not
the one that built them. Everything else under `watch/bin/` stays ignored.

| File | For | Build | Defaults |
|---|---|---|---|
| `FIWeatherWatch-Peter-v0.1.4.zip` | Peter | v0.1.4, `fenix847mm` | Karjaa · Hanko Russarö · Suomenlahti buoy |

The zip contains the `.prg`, its settings JSON and sideload instructions written
for the tester rather than for us.

`fenix847mm` covers quatix 8 as well — the two are API-identical and quatix has
no separate simulator profile.

## Making another one

Defaults are compiled in, so a per-tester build means editing
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
