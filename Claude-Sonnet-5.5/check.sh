#!/usr/bin/env bash
# Prüft den Arbeitsstand von MorphHealth von der Formatierung bis zum Gerätetest.
#
#   ./check.sh [--no-build] [--no-device] [--require-device] [--quick]
#
#   --no-build        vorhandene Artefakte prüfen, nichts neu bauen
#   --no-device       den Gerätetest auf dem Emulator auslassen
#   --require-device  ein nicht erreichbarer Emulator zählt als Fehler (sonst: übersprungen)
#   --quick           entspricht --no-build --no-device
#
# Schritte:
#   1. Lieferumfang (Dateien, Prüfsumme des Auftrags)
#   2. Formatierung und statische Analyse
#   3. flutter test (Kern, Oberfläche, Barrierefreiheit)
#   4. ./build.sh all und Prüfung der APK (Package, x86_64, Berechtigungen, Signatur)
#   5. tools/cli_e2e.py: der Wartungszugang ./mh gegen das gebaute Programm
#   6. tools/device_smoke.py: die Release-APK auf dem Referenzemulator
#
# Temporäre Dateien liegen unter .check-tmp im Projekt und werden am Ende entfernt.
# Endet mit 0, wenn alle ausgeführten Schritte bestanden haben.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

BUILD=1
DEVICE=1
REQUIRE_DEVICE=0
for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    --no-device) DEVICE=0 ;;
    --require-device) REQUIRE_DEVICE=1 ;;
    --quick) BUILD=0; DEVICE=0 ;;
    -h|--help) sed -n '2,19p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "check.sh: unbekannte Option: $arg" >&2; exit 2 ;;
  esac
done

LOGS="$ROOT/.check-tmp/logs"
rm -rf "$ROOT/.check-tmp"
mkdir -p "$LOGS"
trap 'rm -rf "$ROOT/.check-tmp"' EXIT

FAILED=()
SUMMARY=()
LAST_LOG=""

# step NAME BEFEHL...: führt den Befehl aus, zeichnet Dauer und Ergebnis auf, gibt bei Fehlern das Ende des Protokolls aus.
step() {
  local name="$1"; shift
  local log="$LOGS/$(printf '%s' "$name" | tr -c 'A-Za-z0-9' '_').log"
  LAST_LOG="$log"
  local t0=$SECONDS
  echo "== $name"
  if ("$@") >"$log" 2>&1; then
    SUMMARY+=("bestanden  $((SECONDS - t0)) s  $name")
    echo "   bestanden ($((SECONDS - t0)) s)"
  else
    local rc=$?
    FAILED+=("$name")
    SUMMARY+=("FEHLER     $((SECONDS - t0)) s  $name (Exit $rc)")
    echo "   FEHLER (Exit $rc), Ende des Protokolls:"
    tail -n 30 "$log" | sed 's/^/   | /'
  fi
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "check.sh: $1 fehlt im PATH" >&2; exit 2; }; }
need python3
need flutter
need dart

# Werte der Umgebung (schreibgeschützte ENVIRONMENT.json)
env_value() { python3 -c "import json,sys; d=json.load(open('$ROOT/ENVIRONMENT.json')); print(eval(sys.argv[1]))" "$1"; }
SDK="$(env_value "d['toolchain']['android_sdk_path']")"
BT="$(env_value "d['toolchain']['android_build_tools']")"
SPEC_SHA="$(env_value "d['spec_sha256']")"

# --- 1. Lieferumfang -----------------------------------------------------------
check_deliverables() {
  local missing=0
  for f in app/lib/main.dart app/pubspec.yaml app/pubspec.lock artifacts/morphhealth.apk README.md SECURITY.md SPEC.md; do
    [[ -f "$f" ]] || { echo "fehlt: $f"; missing=1; }
  done
  for f in build.sh check.sh mh; do
    [[ -x "$f" ]] || { echo "nicht ausführbar oder fehlt: $f"; missing=1; }
  done
  local actual
  actual="$(sha256sum SPEC.md | cut -d' ' -f1)"
  [[ "$actual" == "$SPEC_SHA" ]] || { echo "SPEC.md weicht von ENVIRONMENT.json ab ($actual)"; missing=1; }
  return "$missing"
}
step "Lieferumfang" check_deliverables

# --- 2. Formatierung und statische Analyse ----------------------------------------
format_check() {
  cd "$ROOT/app"
  # Das Paketverzeichnis (.dart_tool) macht analysis_options.yaml (mit der Formatbreite) für den Formatierer lesbar;
  # die Breite steht zusätzlich hier, damit die Prüfung auch ohne Paketauflösung dasselbe Ergebnis liefert.
  flutter pub get --enforce-lockfile > /dev/null 2>&1 || true
  dart format --page-width 120 --output=none --set-exit-if-changed lib/*.dart lib/core lib/platform lib/state lib/ui bin test
}
analyze() {
  cd "$ROOT/app"
  flutter analyze
}
step "Formatierung (dart format)" format_check
step "Statische Analyse (flutter analyze)" analyze

# --- 3. Tests ------------------------------------------------------------------
run_tests() {
  cd "$ROOT/app"
  flutter test
}
step "Tests (flutter test)" run_tests
echo "   $(grep -Eo '\+[0-9]+: All tests passed' "$LAST_LOG" | tail -1 || true)"

# --- 4. Build und APK ----------------------------------------------------------
apk_check() {
  local aapt2="$SDK/build-tools/$BT/aapt2"
  local apksigner="$SDK/build-tools/$BT/apksigner"
  local apk="$ROOT/artifacts/morphhealth.apk"
  local badging
  badging="$("$aapt2" dump badging "$apk")"
  grep -q "package: name='de.themorpheus.morphhealth.local'" <<<"$badging" || { echo "falsche Package-ID"; return 1; }
  grep -q "native-code:.*'x86_64'" <<<"$badging" || { echo "keine x86_64-Bibliotheken"; return 1; }
  local perms
  perms="$(grep -o "uses-permission: name='[^']*'" <<<"$badging" | sort)"
  echo "$perms"
  grep -q "uses-permission: name='android.permission.INTERNET'" <<<"$perms" || { echo "INTERNET fehlt"; return 1; }
  # Außer INTERNET ist nur die von AndroidX Core eingefügte app-eigene Signaturberechtigung erlaubt.
  if grep -v "android.permission.INTERNET\|DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" <<<"$perms"; then
    echo "unerwartete Berechtigungen"
    return 1
  fi
  "$apksigner" verify --verbose "$apk" | head -5
  [[ -x "$ROOT/artifacts/mh-cli" ]] || { echo "artifacts/mh-cli fehlt"; return 1; }
}
if [[ $BUILD -eq 1 ]]; then
  step "Build (build.sh all)" "$ROOT/build.sh" all
fi
step "APK und Kommandozeilenprogramm" apk_check

# --- 5. Wartungszugang ----------------------------------------------------------
step "Wartungszugang ./mh (Ende zu Ende)" python3 "$ROOT/tools/cli_e2e.py"
echo "   $(grep -E 'CLI-Prüfung:' "$LAST_LOG" | tail -1 || true)"

# --- 6. Gerätetest --------------------------------------------------------------
if [[ $DEVICE -eq 1 ]]; then
  echo "== Gerätetest auf dem Referenzemulator (dauert einige Minuten)"
  t0=$SECONDS
  set +e
  python3 "$ROOT/tools/device_smoke.py" >"$LOGS/device.log" 2>&1
  rc=$?
  set -e
  tail -n 4 "$LOGS/device.log" | sed 's/^/   /'
  if [[ $rc -eq 0 ]]; then
    SUMMARY+=("bestanden  $((SECONDS - t0)) s  Gerätetest")
  elif [[ $rc -eq 3 && $REQUIRE_DEVICE -eq 0 ]]; then
    SUMMARY+=("übersprungen  Gerätetest (Emulator nicht erreichbar)")
  else
    FAILED+=("Gerätetest")
    SUMMARY+=("FEHLER     $((SECONDS - t0)) s  Gerätetest (Exit $rc)")
    grep -E "FAIL|FEHLGESCHLAGEN" "$LOGS/device.log" | head -20 | sed 's/^/   | /'
  fi
else
  SUMMARY+=("ausgelassen  Gerätetest (--no-device)")
fi

echo
echo "Ergebnis"
printf '  %s\n' "${SUMMARY[@]}"
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "Fehlgeschlagen: ${FAILED[*]}"
  exit 1
fi
echo "Alle ausgeführten Schritte bestanden."
