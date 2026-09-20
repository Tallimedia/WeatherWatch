# FIWeatherWatch — watch app

Connect IQ widget. Four pages — Land, Sea, Waves, About — plus a glance, against
the live backend at `weatherapp.tallimedia.com`. About carries the FMI attribution
that CC BY 4.0 requires in the app itself.

Design decisions and the reasoning behind them live in `../RESEARCH.md`
(owned by the `claude-docs` repo); section references in the source point there.

## Build and run

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/current/bin:$PATH"

connectiq &                                     # launch the simulator once
monkeyc -o bin/fiweatherwatch.prg -f monkey.jungle \
        -y ~/.garmin-ciq/developer_key.der -d fenix847mm -w
monkeydo bin/fiweatherwatch.prg fenix847mm
```

## Release builds

```bash
./build-release.sh                  # bin/fiweatherwatch-<version>.iq for the store
./build-release.sh fenix847mm       # also bin/fiweatherwatch-<version>-<device>.prg
```

Outputs carry the version because they outlive the build: an undated `.prg` in
`bin/` cannot be told from a current one, and sideloading a stale build looks
exactly like a fix that did not work. The script refuses to package if
`manifest.xml` and `Config.VERSION` disagree — the store tracks the manifest,
testers read what the app draws, and a mismatch means a bug report naming a
build that never shipped.

**Bump the version before rebuilding anything already uploaded.** The store
rejects a repeated number, and two different binaries sharing one number makes a
tester's report unplaceable. See `../CHANGELOG.md`.

`fenix847mm` is the development target — quatix 8 is API-identical and has no
separate simulator profile. The full VolvoWatch product list gets copied into
the manifest before release.

**The simulator makes real web requests**, so the app is talking to the
production backend, not a mock.

## Pages

| | Page | Shows |
|---|---|---|
| Glance | — | Two configurable fields, coloured on a threshold breach |
| 1 | Land | Temperature (blue/red on the cold/hot band), wind with gust, 6-hourly forecast, station name + distance + per-field age |
| 2 | Sea | Station wind and gust, direction arrow, air temperature, age |
| 3 | Waves | Significant height, period, direction arrow, water temperature; labelled when modelled rather than measured |

Up/down or swipe moves between pages; select refreshes.

## Settings

Thirteen, in four groups — Land, Sea, Display, Units. Edited in Garmin Connect
Mobile. Everything has a default, so the app works untouched: Helsinki, Harmaja,
nearest buoy.

In the simulator: **Settings → Edit Persistent Storage / Properties** to change
them without a phone.

## Structure

| File | Does |
|---|---|
| `Api.mc` | Backend client, response cache in `Application.Storage` |
| `Config.mc` | Settings access with defaults; derives the gust limits |
| `Fmt.mc` | Units, compass points, ages, clock |
| `Theme.mc` | Threshold-driven colours |
| `Pages.mc` | Page rendering |
| `PageView.mc` | The view and page navigation |
| `GlanceView.mc` | Glance card |
