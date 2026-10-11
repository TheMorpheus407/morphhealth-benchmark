#!/usr/bin/env bash
# MorphHealth — Prüf-Skript (SPEC P12).
#
# Führt aus:
#   1. flutter analyze   (statische Analyse, app/)
#   2. flutter test      (Unit-/Widget-Tests, app/)
#   3. Artefakt-Prüfung  (artifacts/morphhealth.apk, mh)
#   4. mh-Smoke-Test    (describe + portable.export gegen temporären Bestand)
#
# Bricht bei jedem Fehler ab (set -e). Dauer: mehrere Minuten.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"

FLUTTER="${FLUTTER:-}"
if [[ -z "$FLUTTER" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER="$(command -v flutter)"
  else
    FLUTTER="/run/current-system/sw/bin/flutter"
  fi
fi

cd "$APP"

echo "==> [1/4] flutter analyze"
"$FLUTTER" analyze

echo "==> [2/4] flutter test"
"$FLUTTER" test

echo "==> [3/4] Artefakte prüfen"
APK="$ROOT/artifacts/morphhealth.apk"
MH="$ROOT/mh"
[[ -f "$APK" ]] || { echo "FEHLER: $APK fehlt — zuerst ./build.sh ausführen." >&2; exit 1; }
[[ -x "$MH" ]] || { echo "FEHLER: $MH fehlt oder ist nicht ausführbar — zuerst ./build.sh ausführen." >&2; exit 1; }
ls -l "$APK" "$MH"

echo "==> [4/4] mh-Smoke-Test (describe + portable.export)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DATA="$TMP/data"
KEY="$TMP/master.key"
mkdir -p "$DATA"
# Schlüsseldatiei: 32 rohe Bytes, außerhalb des Datenverzeichnisses.
head -c 32 /dev/urandom > "$KEY"

RESP="$(printf '%s\n' '{"request_id":"smoke-1","op":"describe"}' | "$MH" --data-dir "$DATA" --key-file "$KEY")"
echo "$RESP" | python3 -c '
import json, sys
r = json.loads(sys.stdin.read().strip().splitlines()[-1])
assert r["request_id"] == "smoke-1", r
assert r["ok"] is True, r
assert "data" in r and "data_formats" in r["data"], r["data"].keys()
print("describe: ok (request_id konsistent, ok=true, data.data_formats vorhanden)")
'

RESP2="$(printf '%s\n' '{"request_id":"smoke-2","op":"portable.export","ack_plaintext":true}' | "$MH" --data-dir "$DATA" --key-file "$KEY")"
echo "$RESP2" | python3 -c '
import json, sys
r = json.loads(sys.stdin.read().strip().splitlines()[-1])
assert r["request_id"] == "smoke-2", r
assert r["ok"] is True, r
# portable.export liefert das Dokument direkt als data (Top-Level: format,
# format_version, generator, data).
doc = r["data"]
assert doc["format"] == "morphhealth.portable", doc.get("format")
assert doc["format_version"] == 1, doc.get("format_version")
assert set(doc["data"].keys()) >= {
    "settings", "foods", "nutrition_entries", "water_entries",
    "caffeine_entries", "periods", "weight_entries", "symptom_entries",
}, doc["data"].keys()
print("portable.export: ok (Format morphhealth.portable v1, leerer Bestand, 8 Datenfelder)")
'

echo "==> Alle Prüfungen bestanden."
