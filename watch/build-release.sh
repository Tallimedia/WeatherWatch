#!/usr/bin/env bash
# Build the .iq package for a Connect IQ Store upload (beta or public).
#
#   ./build-release.sh              -> bin/fiweatherwatch-<version>.iq
#   ./build-release.sh quatix8      -> also bin/fiweatherwatch-<version>-quatix8.prg
#
# On the beta app id, every output filename is forced to carry "Beta" too
# (bin/fiweatherwatch-v<version>Beta.iq) — not optional, not branch-name
# based. See the BETA_APP_ID check below for why.
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

# The beta app id is the authoritative "is this a beta build" signal — not
# the git branch name, which is just a human label and could drift or be
# checked out under an unexpected name. If this id is in manifest.xml, every
# output filename must carry "Beta" too: a beta binary that looks like a
# production one by its filename alone is exactly how a beta gets uploaded
# to the wrong store entry, or a stale beta gets sideloaded mistaken for the
# real release. Nico's rule, 2026-10-09, after a build this same session
# produced "fiweatherwatch-1.2.0.iq" — no "Beta" in it at all.
BETA_APP_ID="8a6b649545ae422aa7d00cc7fa6263b4"
if grep -q "id=\"$BETA_APP_ID\"" manifest.xml; then
  NAME_V="v${manifest_v}Beta"
else
  NAME_V="$manifest_v"
fi

OUT="bin/fiweatherwatch-$NAME_V.iq"

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
  PRG="bin/fiweatherwatch-$NAME_V-$DEVICE.prg"
  printf '\nbuilding %s…\n' "$PRG"
  monkeyc -d "$DEVICE" -o "$PRG" -f monkey.jungle -y "$KEY" -w
  printf '\n\033[32mOK:\033[0m %s  (%s bytes)\n' "$PRG" "$(stat -f%z "$PRG")"
  printf 'Copy to GARMIN/APPS/ and its -settings.json to GARMIN/APPS/SETTINGS/.\n'
fi
