#!/usr/bin/env bash
# Baut MorphHealth aus den Quellen in app/:
#   artifacts/morphhealth.apk  Release-APK (Android, x86_64 und arm64-v8a)
#   artifacts/mh-cli           nativer Wartungszugang (wird vom Starter ./mh aufgerufen)
#
# Aufruf:  ./build.sh [all|apk|cli]      (Voreinstellung: all)
#
# Die Lebensmittel-API (Ursprung und User-Agent) steht nicht im Fachcode. Der
# Build übernimmt die Vorgaben aus ENVIRONMENT.json (nur lesend) als
# Compile-Zeit-Standard; MH_FOOD_BASE_URL und MH_FOOD_USER_AGENT überschreiben
# sie. Ohne beides gilt https://world.openfoodfacts.org. Zur Laufzeit lassen
# sich beide Werte weiter ändern (App: Einstellungen, mh: Optionen).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"
ART="$ROOT/artifacts"
TARGET="${1:-all}"

case "$TARGET" in
  all | apk | cli) ;;
  *) echo "Aufruf: $0 [all|apk|cli]" >&2; exit 2 ;;
esac

need() {
  command -v "$1" > /dev/null 2>&1 || { echo "build.sh: '$1' fehlt im PATH" >&2; exit 1; }
}
need flutter
need dart
need python3

read_env() {
  python3 - "$ROOT/ENVIRONMENT.json" "$1" << 'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        print(json.load(f).get(sys.argv[2], "") or "")
except OSError:
    print("")
PY
}

BASE_URL="${MH_FOOD_BASE_URL:-$(read_env food_api_base_url)}"
USER_AGENT="${MH_FOOD_USER_AGENT:-$(read_env food_api_user_agent)}"
DEFINES=()
[[ -n "$BASE_URL" ]] && DEFINES+=("MH_FOOD_BASE_URL=$BASE_URL")
[[ -n "$USER_AGENT" ]] && DEFINES+=("MH_FOOD_USER_AGENT=$USER_AGENT")
echo "build.sh: Lebensmittel-API ${BASE_URL:-https://world.openfoodfacts.org (Vorgabe)}"

mkdir -p "$ART"
cd "$APP"

# Abhängigkeiten exakt nach pubspec.lock (gesperrt).
flutter pub get --enforce-lockfile
# Übersetzungen (lib/l10n/*.arb) in Dart-Code umsetzen.
flutter gen-l10n

if [[ "$TARGET" == "all" || "$TARGET" == "apk" ]]; then
  FLAGS=()
  for d in "${DEFINES[@]}"; do FLAGS+=("--dart-define=$d"); done
  flutter build apk --release --target-platform android-x64,android-arm64 "${FLAGS[@]}"
  cp "$APP/build/app/outputs/flutter-apk/app-release.apk" "$ART/morphhealth.apk"
  echo "build.sh: $ART/morphhealth.apk ($(du -h "$ART/morphhealth.apk" | cut -f1), sha256 $(sha256sum "$ART/morphhealth.apk" | cut -d' ' -f1))"
  # Paketkennung und ABIs prüfen, falls die Build-Tools des SDK erreichbar sind.
  AAPT2="$(ls -d "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"/build-tools/*/aapt2 2> /dev/null | sort -V | tail -1 || true)"
  if [[ -n "$AAPT2" ]]; then
    "$AAPT2" dump badging "$ART/morphhealth.apk" | grep -E "^(package|native-code|sdkVersion|targetSdkVersion|uses-permission)" | sed 's/^/build.sh:   /'
  fi
fi

if [[ "$TARGET" == "all" || "$TARGET" == "cli" ]]; then
  FLAGS=()
  for d in "${DEFINES[@]}"; do FLAGS+=("-D$d"); done
  dart compile exe bin/mh.dart -o "$ART/mh-cli" "${FLAGS[@]}"
  echo "build.sh: $ART/mh-cli ($(du -h "$ART/mh-cli" | cut -f1))"
fi
