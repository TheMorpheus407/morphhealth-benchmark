#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-/home/morpheus/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

FOOD_URL="https://world.openfoodfacts.org"
FOOD_UA="MorphHealth/1.0"

if [[ -f "$ROOT_DIR/ENVIRONMENT.json" ]]; then
  readarray -t ENV_VALS < <(python3 - "$ROOT_DIR/ENVIRONMENT.json" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
print(data.get("food_api_base_url", "https://world.openfoodfacts.org"))
print(data.get("food_api_user_agent", "MorphHealth/1.0"))
PY
  )
  FOOD_URL="${ENV_VALS[0]}"
  FOOD_UA="${ENV_VALS[1]}"
fi

mkdir -p "$ROOT_DIR/artifacts"

echo "[1/3] Resolving locked Dart/Flutter dependencies..."
cd "$ROOT_DIR/app"
flutter pub get --enforce-lockfile

echo "[2/3] Compiling local maintenance binary ./mh (artifacts/mh-bin)..."
dart compile exe bin/mh.dart -o "$ROOT_DIR/artifacts/mh-bin"
chmod +x "$ROOT_DIR/mh" "$ROOT_DIR/artifacts/mh-bin"

echo "[3/3] Building Android release APK (Package-ID: de.themorpheus.morphhealth.local)..."
flutter build apk --release \
  --dart-define="FOOD_API_BASE_URL=$FOOD_URL" \
  --dart-define="FOOD_API_USER_AGENT=$FOOD_UA"

cp "$ROOT_DIR/app/build/app/outputs/flutter-apk/app-release.apk" \
   "$ROOT_DIR/artifacts/morphhealth.apk"

python3 - "$ROOT_DIR/artifacts/morphhealth.apk" <<'PY'
import sys, zipfile
apk = sys.argv[1]
with zipfile.ZipFile(apk, "r") as zf:
    names = set(zf.namelist())
assert "lib/x86_64/libapp.so" in names, "Missing x86_64 native library in APK!"
print(f"Verified APK: {apk} (includes lib/x86_64/libapp.so)")
PY
