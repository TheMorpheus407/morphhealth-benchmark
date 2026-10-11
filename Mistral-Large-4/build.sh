#!/usr/bin/env bash
# MorphHealth — Build-Skript (SPEC P09).
#
# Erzeugt im Arbeitsverzeichnis:
#   artifacts/morphhealth.apk  Release-APK (x86_64, de.themorpheus.morphhealth.local)
#   mh                         Wartungszugang (SPEC P10), kompiliert aus app/bin/mh.dart
#
# App-Version und Open-Food-Facts-Origin werden per --dart-define in die App
# und in den Wartungszugang einkompiliert (Werte aus ENVIRONMENT.json;
# Fachcode-Default für Produktinstallationen: https://world.openfoodfacts.org).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"
ARTIFACTS="$ROOT/artifacts"

# --- Toolchain -------------------------------------------------------------
FLUTTER="${FLUTTER:-}"
if [[ -z "$FLUTTER" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER="$(command -v flutter)"
  else
    FLUTTER="/run/current-system/sw/bin/flutter"
  fi
fi
DART="$(dirname "$FLUTTER")/dart"

# Gradle-JDK (ENVIRONMENT.json: jdk_used_by_flutter_gradle, JBR 21.0.10).
# Falls der nix-Store-Pfad nicht mehr existiert: erstes passendes JBR nehmen,
# sonst System-JDK auf PATH.
JBR="/nix/store/ffa3jyw306nvblvbzbqn1n1bwpz9varg-android-studio-unwrapped-2025.3.4.7/jbr"
if [[ ! -d "$JBR" ]]; then
  JBR="$(ls -d /nix/store/*-android-studio-unwrapped-*/jbr 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "${JAVA_HOME:-}" && -d "$JBR" ]]; then
  export JAVA_HOME="$JBR"
fi
# Android-SDK (ENVIRONMENT.json: android_sdk_path).
export ANDROID_HOME="${ANDROID_HOME:-/home/morpheus/Android/Sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/home/morpheus/Android/Sdk}"

# --- Konstanten (ENVIRONMENT.json) -----------------------------------------
APP_VERSION="1.0.0+1"
FOOD_API_BASE_URL="https://localhost:8788"
FOOD_API_USER_AGENT="MorphHealth/1.0-rc3 (benchmark build)"

DART_DEFINES=(
  --dart-define="MH_APP_VERSION=$APP_VERSION"
  --dart-define="FOOD_API_BASE_URL=$FOOD_API_BASE_URL"
  --dart-define="FOOD_API_USER_AGENT=$FOOD_API_USER_AGENT"
)

mkdir -p "$ARTIFACTS"
cd "$APP"

echo "==> flutter: $FLUTTER"
echo "==> pub get"
"$FLUTTER" pub get

echo "==> Release-APK (android-x64) mit dart-defines:"
printf '    %s\n' "${DART_DEFINES[@]}"
"$FLUTTER" build apk --release --target-platform android-x64 "${DART_DEFINES[@]}"
install -m 0644 build/app/outputs/flutter-apk/app-release.apk "$ARTIFACTS/morphhealth.apk"

echo "==> Wartungszugang mh (dart build cli, AOT)"
# Hinweis: `dart compile exe` verweigert Flutter-Pakete wegen der Build-Hooks
# der Plugin-Abhängigkeiten (path_provider/file_picker). `dart build cli`
# unterstützt Hooks und erzeugt ein eigenständiges AOT-Binary. Die fachlichen
# Defaults (Version, Food-API-Origin) kommen zur Laufzeit aus dem Starter
# `mh` im Wurzelverzeichnis (Umgebungsvariablen MH_FOOD_BASE_URL /
# MH_FOOD_USER_AGENT, siehe app/bin/mh.dart).
rm -rf "$ARTIFACTS/mh-cli"
"$DART" build cli -o "$ARTIFACTS/mh-cli"
test -x "$ARTIFACTS/mh-cli/bundle/bin/mh"

echo "==> Artefakte:"
ls -l "$ARTIFACTS/morphhealth.apk" "$ARTIFACTS/mh-cli/bundle/bin/mh"
echo "==> Build abgeschlossen."
