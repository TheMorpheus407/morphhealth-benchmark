#!/usr/bin/env bash
# Prüft den Arbeitsstand von MorphHealth.
#
# Aufruf:  ./check.sh [--device] [--offline]
#
#   --device    bedient zusätzlich die APK auf dem Referenzgerät
#               (installiert sie und LÖSCHT dort die Daten der App)
#   --offline   überspringt die Schritte, die den Lebensmitteldienst aus
#               ENVIRONMENT.json brauchen
#
# Schritte:
#   1  Abhängigkeiten entsprechen app/pubspec.lock
#   2  Quelltext ist formatiert (dart format)
#   3  statische Analyse der App und des Fachkerns
#   4  Tests des Fachkerns (dart test)
#   5  Tests der Oberfläche (flutter test)
#   6  Wartungszugang: aus den Quellen bauen, als Prozess bedienen
#   7  APK: Package-ID, x86_64, Berechtigungen, Manifest, Signatur, Aktualität
#   8  mit --device: Kernabläufe auf dem Referenzgerät, Bildschirmfotos nach
#      docs/screenshots/
#
# Jeder Schritt läuft, auch wenn ein früherer fehlschlägt. Das Ergebnis steht
# am Ende und in artifacts/check-report.txt; die vollständigen Ausgaben liegen
# in artifacts/check-logs/. Rückgabewert 0 nur, wenn alles bestanden ist.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"
CORE="$APP/packages/morphhealth_core"
OUT="$ROOT/artifacts"
LOGS="$OUT/check-logs"
REPORT="$OUT/check-report.txt"

with_device=0
offline=()
for arg in "$@"; do
  case "$arg" in
    --device) with_device=1 ;;
    --offline) offline=(--offline) ;;
    -h | --help)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "check.sh: unbekannte Option: $arg" >&2
      exit 64
      ;;
  esac
done

mkdir -p "$LOGS"
rm -f "$LOGS"/*.log
failed=0
results=()

# step NUMMER NAME BEFEHL…  – führt den Befehl aus, hält Ausgabe und Ergebnis fest.
step() {
  local id="$1" name="$2"
  shift 2
  local log="$LOGS/$id.log" started=$SECONDS status summary
  printf '%s  %s … ' "$id" "$name"
  if "$@" >"$log" 2>&1; then status="ok"; else status="FEHLER"; fi
  # Letzte Zeile mit Inhalt als Kurzfassung (ohne Steuerzeichen).
  summary="$(grep -v '^[[:space:]]*$' "$log" | tail -n 1 | tr -d '\r' | cut -c1-110)"
  printf '%s (%ss)\n' "$status" "$((SECONDS - started))"
  results+=("$(printf '%-6s %s  %s' "$status" "$id" "$name")")
  results+=("         $summary")
  if [ "$status" != "ok" ]; then
    failed=1
    echo "---- Ende der Ausgabe von Schritt $id ($log) ----"
    tail -n 25 "$log"
    echo "----"
  fi
}

flutter_root() {
  flutter --version --machine 2>/dev/null | python3 -I -c '
import json, sys
print(json.load(sys.stdin)["flutterRoot"])'
}

# Die APK muss aus dem jetzigen Quellstand stammen.
apk_is_current() {
  local apk="$OUT/morphhealth.apk" newer
  [ -f "$apk" ] || {
    echo "artifacts/morphhealth.apk fehlt; zuerst ./build.sh ausführen"
    return 1
  }
  newer="$(find "$APP/lib" "$APP/pubspec.yaml" "$APP/pubspec.lock" \
    "$APP/android/app/src" "$APP/android/app/build.gradle.kts" \
    "$CORE/lib" "$ROOT/ENVIRONMENT.json" -type f -newer "$apk" | head -n 5)"
  if [ -n "$newer" ]; then
    echo "Die APK ist älter als diese Quellen; ./build.sh ausführen:"
    echo "$newer"
    return 1
  fi
  echo "Die APK ist neuer als alle Quellen."
}

cd "$APP" || exit 1
step 1 "Abhängigkeiten nach pubspec.lock" flutter pub get --enforce-lockfile
step 2 "Formatierung" \
  dart format --output=none --set-exit-if-changed lib test packages/morphhealth_core
step 3a "Statische Analyse der App" flutter analyze --no-pub
step 3b "Statische Analyse des Fachkerns" \
  bash -c "cd '$CORE' && dart analyze --fatal-infos"
# Der Kern liegt im Arbeitsbereich einer Flutter-App; dart braucht dafür den
# Ort des Flutter-SDK.
FLUTTER_ROOT="${FLUTTER_ROOT:-$(flutter_root)}"
export FLUTTER_ROOT
step 4 "Tests des Fachkerns" bash -c "cd '$CORE' && dart test --reporter expanded"
step 5 "Tests der Oberfläche" flutter test --no-pub --reporter expanded
step 6a "Wartungszugang bauen" "$ROOT/build.sh" --mh-only
step 6b "Wartungszugang bedienen" python3 -I "$ROOT/tools/mh_check.py" "${offline[@]}"
step 7a "APK ist aktuell" apk_is_current
step 7b "APK prüfen" python3 -I "$ROOT/tools/apk_check.py"
if [ "$with_device" = 1 ]; then
  # Die Bildschirmfotos dieses Laufs ersetzen die bisherigen.
  step 8 "Abläufe auf dem Referenzgerät" \
    python3 -I "$ROOT/tools/device_check.py" --reset-app-data \
    --screenshots "$ROOT/docs/screenshots" "${offline[@]}"
else
  results+=("--     8  Abläufe auf dem Referenzgerät (nur mit --device)")
fi

{
  echo "MorphHealth – Prüfbericht vom $(date +%Y-%m-%dT%H:%M:%S%z)"
  echo "Aufruf: ./check.sh $*"
  echo "Flutter: $(flutter --version 2>/dev/null | head -n 1)"
  echo "Dart: $(dart --version 2>&1 | head -n 1)"
  if [ -f "$OUT/morphhealth.apk" ]; then
    echo "APK: $(sha256sum "$OUT/morphhealth.apk" | cut -d' ' -f1)"
  fi
  echo
  printf '%s\n' "${results[@]}"
  echo
  if [ "$failed" = 0 ]; then echo "Ergebnis: alles bestanden"; else echo "Ergebnis: FEHLER"; fi
} >"$REPORT"

echo
cat "$REPORT"
exit "$failed"
