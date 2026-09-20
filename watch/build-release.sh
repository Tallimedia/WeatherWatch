#!/usr/bin/env bash
# Build the .iq package for a Connect IQ Store upload (beta or public).
#
#   ./build-release.sh              -> bin/fiweatherwatch-<version>.iq
#   ./build-release.sh quatix8      -> also bin/fiweatherwatch-<version>-quatix8.prg
#
# Outputs carry the version because they outlive the build: a bin/ holding one
# undated fiweatherwatch.prg gives no way to tell a current sideload from a
# stale one, and sideloading the stale one looks like the fix never worked.
#
# Refuses to build if the version in manifest.xml and Config.VERSION disagree —
# the store tracks the manifest, testers read what the app draws, and a mismatch
# means a bug report naming a build that was never shipped.
set -euo pipefail

cd "$(dirname "$0")"

KEY="${CIQ_DEVELOPER_KEY:-$HOME/.garmin-ciq/developer_key.der}"
DEVICE="${1:-}"

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export PATH="$JAVA_HOME/bin:$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/current/bin:$PATH"

fail() { printf '\n\033[31mERROR:\033[0m %s\n\n' "$1" >&2; exit 1; }

[ -f "$KEY" ] || fail "developer key not found at $KEY"

manifest_v=$(grep -oE 'version="[0-9]+\.[0-9]+\.[0-9]+"' manifest.xml | head -1 | cut -d'"' -f2)
code_v=$(grep -oE 'const VERSION = "[^"]+"' source/Config.mc | cut -d'"' -f2)

[ -n "$manifest_v" ] || fail "no version found in manifest.xml"
[ "$manifest_v" = "$code_v" ] || \
  fail "version mismatch: manifest.xml says $manifest_v, Config.VERSION says $code_v"

OUT="bin/fiweatherwatch-$manifest_v.iq"

printf 'building v%s for %s devices…\n' \
  "$manifest_v" "$(grep -c '<iq:product ' manifest.xml)"

monkeyc -e -o "$OUT" -f monkey.jungle -y "$KEY" -w

printf '\n\033[32mOK:\033[0m %s  (%s bytes)  v%s\n' \
  "$OUT" "$(stat -f%z "$OUT")" "$manifest_v"
printf 'Upload at https://apps.garmin.com/developer/dashboard — set the release to BETA.\n'

# A .prg is per-device and is what goes on the watch over USB, so it is only
# built when a device is named.
if [ -n "$DEVICE" ]; then
  grep -q "\"$DEVICE\"" manifest.xml || \
    fail "device '$DEVICE' is not in manifest.xml"
  PRG="bin/fiweatherwatch-$manifest_v-$DEVICE.prg"
  printf '\nbuilding %s…\n' "$PRG"
  monkeyc -d "$DEVICE" -o "$PRG" -f monkey.jungle -y "$KEY" -w
  printf '\n\033[32mOK:\033[0m %s  (%s bytes)\n' "$PRG" "$(stat -f%z "$PRG")"
  printf 'Copy to GARMIN/APPS/ and its -settings.json to GARMIN/APPS/SETTINGS/.\n'
fi
