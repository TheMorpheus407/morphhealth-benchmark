#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")" && pwd)
export PUB_CACHE="${PUB_CACHE:-$ROOT/.pub-cache}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$ROOT/.gradle}"
export TMPDIR="${TMPDIR:-$ROOT/.tmp}"
mkdir -p "$PUB_CACHE" "$GRADLE_USER_HOME" "$TMPDIR"
cd "$ROOT/app"
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib bin test integration_test
flutter analyze
flutter test
cd "$ROOT"
TEST_ROOT="$ROOT/.tmp/check-mh"
rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT"
python3 - "$TEST_ROOT/key.bin" <<'PY'
import os,sys
with open(sys.argv[1], 'wb') as key:
    key.write(os.urandom(32))
PY
printf '%s\n' \
  '{"request_id":"describe","op":"describe"}' \
  '{"request_id":"day","op":"nutrition.day","date":"2026-01-01"}' \
  '{"request_id":"forecast","op":"cycle.forecast","on":"2026-01-01"}' \
  | ./mh --data-dir "$TEST_ROOT/data" --key-file "$TEST_ROOT/key.bin" --now 2026-01-01T00:00:00Z \
  > "$TEST_ROOT/responses.jsonl"
python3 - "$TEST_ROOT/responses.jsonl" <<'PY'
import json,sys
with open(sys.argv[1], encoding='utf-8') as source:
    rows=[json.loads(line) for line in source if line.strip()]
assert [row['request_id'] for row in rows] == ['describe', 'day', 'forecast']
assert all(row['ok'] for row in rows)
assert len(rows[0]['data']['formats']['nutrient_units']) == 31
assert len(rows[1]['data']['totals']) == 31
assert rows[2]['data']['available'] is False
print('JSON-Lines smoke test passed')
PY
SDK=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["toolchain"]["android_sdk_path"])' "$ROOT/ENVIRONMENT.json")
test -f "$ROOT/artifacts/morphhealth.apk"
"$SDK/build-tools/36.1.0/aapt" dump badging "$ROOT/artifacts/morphhealth.apk" | python3 -c '
import sys
line=sys.stdin.readline()
assert "de.themorpheus.morphhealth.local" in line, line
'
python3 - "$ROOT/artifacts/morphhealth.apk" <<'PY'
import sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as apk:
    assert 'lib/x86_64/libflutter.so' in apk.namelist()
    assert 'lib/x86_64/libapp.so' in apk.namelist()
print('APK package and x86_64 checks passed')
PY
if [[ "${MH_LIVE_TESTS:-0}" == "1" ]]; then
  printf '%s\n' '{"request_id":"live","op":"food.lookup","barcode":"4000405002377"}' \
    | ./mh --data-dir "$TEST_ROOT/live-data" --key-file "$TEST_ROOT/key.bin" \
    | python3 -c 'import json,sys; row=json.loads(sys.stdin.readline()); assert row["ok"] and row["data"]["found"]; print("Live food lookup passed")'
fi
if [[ "${MH_ANDROID_TESTS:-0}" == "1" ]]; then
  ADB=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["toolchain"]["adb_path"])' "$ROOT/ENVIRONMENT.json")
  "$ADB" -s emulator-5560 get-state
  "$ADB" -s emulator-5560 reverse tcp:8788 tcp:8788
  BASE=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["food_api_base_url"])' "$ROOT/ENVIRONMENT.json")
  UA=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["food_api_user_agent"])' "$ROOT/ENVIRONMENT.json")
  cd "$ROOT/app"
  flutter test integration_test/app_flow_test.dart \
    -d emulator-5560 \
    --dart-define="FOOD_BASE_URL=$BASE" \
    --dart-define="FOOD_USER_AGENT=$UA"
fi
printf 'All checks passed\n'
