#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")" && pwd)
export PUB_CACHE="${PUB_CACHE:-$ROOT/.pub-cache}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT/.gradle}"
export TMPDIR="${TMPDIR:-$ROOT/.tmp}"
mkdir -p "$PUB_CACHE" "$GRADLE_USER_HOME" "$TMPDIR" "$ROOT/artifacts"
BASE=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["food_api_base_url"])' "$ROOT/ENVIRONMENT.json")
UA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["food_api_user_agent"])' "$ROOT/ENVIRONMENT.json")
SDK=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["toolchain"]["android_sdk_path"])' "$ROOT/ENVIRONMENT.json")
export ANDROID_HOME="${ANDROID_HOME:-$SDK}"
cd "$ROOT/app"
flutter pub get --enforce-lockfile
flutter build apk \
  --release \
  --target-platform=android-x64 \
  --dart-define="FOOD_BASE_URL=$BASE" \
  --dart-define="FOOD_USER_AGENT=$UA"
dart build cli --target=bin/mh.dart --output="$ROOT/app/build/mh" --verbosity=error
cp "$ROOT/app/build/app/outputs/flutter-apk/app-release.apk" "$ROOT/artifacts/morphhealth.apk"
"$SDK/build-tools/36.1.0/aapt" dump badging "$ROOT/artifacts/morphhealth.apk" | python3 -c '
import sys
line=sys.stdin.readline()
assert "de.themorpheus.morphhealth.local" in line, line
print(line.strip())
'
python3 - "$ROOT/artifacts/morphhealth.apk" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as apk:
    names=set(apk.namelist())
for required in ("lib/x86_64/libflutter.so", "lib/x86_64/libapp.so"):
    assert required in names, f"missing {required}"
print("x86_64 native libraries verified")
PY
sha256sum "$ROOT/artifacts/morphhealth.apk" > "$ROOT/artifacts/morphhealth.apk.sha256"
printf 'Built %s\n' "$ROOT/artifacts/morphhealth.apk"
