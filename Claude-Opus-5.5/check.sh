#!/usr/bin/env bash
# Quality gate for MorphHealth:
#   1. locked dependencies, 2. the shared core stays Flutter-free,
#   3. static analysis, 4. unit and widget tests (incl. 10k-entry performance),
#   5. end-to-end test of the ./mh maintenance process,
#   6. checks of artifacts/morphhealth.apk (package id, x86_64, signature).
# Options:
#   --device   additionally run the integration test on the reference
#              emulator (emulator-5560; replaces the installed app's data!)
#   --online   require the food API from ENVIRONMENT.json for the mh test
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"
RUN_DEVICE=0
REQUIRE_ONLINE=0
for arg in "$@"; do
  case "$arg" in
    --device) RUN_DEVICE=1 ;;
    --online) REQUIRE_ONLINE=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

step() { echo; echo "==> $*"; }

step "Toolchain"
flutter --version | head -n 1
dart --version

cd "$APP"
step "Dependencies (pubspec.lock enforced)"
flutter pub get --enforce-lockfile

step "Shared core must not depend on Flutter (it is also used by ./mh)"
if grep -rnE "package:flutter|dart:ui" lib/core bin; then
  echo "FAIL: lib/core or bin imports Flutter" >&2
  exit 1
fi
echo "ok"

step "Static analysis"
flutter analyze

step "Unit and widget tests"
flutter test --reporter expanded

step "End-to-end test of ./mh"
WORK="$APP/build/check_mh"
rm -rf "$WORK"
mkdir -p "$WORK"
head -c 32 /dev/urandom > "$WORK/key.bin"
chmod 600 "$WORK/key.bin"
python3 - "$ROOT/mh" "$WORK" "$REQUIRE_ONLINE" <<'PY'
import json, subprocess, sys

mh, work, require_online = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
proc = subprocess.Popen(
    [mh, "--data-dir", f"{work}/data", "--key-file", f"{work}/key.bin",
     "--now", "2026-09-23T10:00:00+02:00"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def call(req):
    proc.stdin.write(json.dumps(req) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    resp = json.loads(line)
    assert resp["request_id"] == req.get("request_id"), resp
    return resp

def check(cond, msg):
    if not cond:
        print("FAIL:", msg)
        sys.exit(1)
    print("ok  ", msg)

d = call({"request_id": 1, "op": "describe"})
check(d["ok"] and "example_document" in d["data"], "describe returns documentation and an example")
imp = call({"request_id": 2, "op": "portable.import", "confirm_replace": True,
            "document": d["data"]["example_document"]})
check(imp["ok"] and imp["data"]["diary_entries"] == 22, "portable.import of the example document")
day = call({"request_id": 3, "op": "nutrition.day", "date": "2026-09-22"})
check(day["ok"] and day["data"]["totals"]["energy_kcal"] == 578.9, "nutrition.day totals (578.9 kcal)")
fc = call({"request_id": 4, "op": "cycle.forecast", "on": "2026-09-23"})
check(fc["ok"] and fc["data"]["next_period"]["expected_start"] == "2026-09-26", "cycle.forecast estimate")
exp = call({"request_id": 5, "op": "portable.export", "ack_plaintext": True})
check(exp["ok"] and len(exp["data"]["food_entries"]) == 4, "portable.export")
bad = call({"request_id": 6, "op": "portable.export"})
check(not bad["ok"] and bad["error"]["code"] == "confirmation_required", "export needs ack_plaintext")
search = call({"request_id": 7, "op": "food.search", "q": "nutella", "page": 1})
if search["ok"]:
    check(search["data"]["online"]["count"] > 0, "food.search returns online results")
    look = call({"request_id": 8, "op": "food.lookup", "barcode": "3017620425035"})
    check(look["ok"] and look["data"]["found"], "food.lookup finds a product")
elif require_online:
    check(False, "food.search online: " + json.dumps(search["error"]))
else:
    print("skip food.search/food.lookup (food API not reachable: %s)" % search["error"]["code"])
proc.stdin.close()
proc.wait(timeout=30)
check(proc.returncode == 0, "process ends with EOF")
PY

APK="$ROOT/artifacts/morphhealth.apk"
if [[ -f "$APK" ]]; then
  step "APK checks"
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
  BUILD_TOOLS="$(ls -d "$SDK"/build-tools/* | sort -V | tail -n 1)"
  "$BUILD_TOOLS/aapt2" dump badging "$APK" | grep -E "^package: name='de\.themorpheus\.morphhealth\.local'" \
    || { echo "FAIL: wrong package id" >&2; exit 1; }
  unzip -l "$APK" | grep -q "lib/x86_64/libapp.so" || { echo "FAIL: no x86_64 code" >&2; exit 1; }
  echo "ok   package id de.themorpheus.morphhealth.local, x86_64 native code present"
  # The SDK wrapper script expects /bin/bash, which NixOS does not have.
  bash "$BUILD_TOOLS/apksigner" verify "$APK" && echo "ok   APK signature verifies"
else
  echo "(artifacts/morphhealth.apk not built yet - run ./build.sh)"
fi

if [[ "$RUN_DEVICE" == 1 ]]; then
  step "Integration test on emulator-5560"
  ENV_FILE="$ROOT/ENVIRONMENT.json"
  ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"
  BASE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["food_api_base_url"])' "$ENV_FILE")"
  UA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["food_api_user_agent"])' "$ENV_FILE")"
  # The food API is reached through adb reverse (localhost on the device).
  PORT="$(python3 -c 'import sys, urllib.parse as u; print(u.urlparse(sys.argv[1]).port or 443)' "$BASE")"
  "$ADB" -s emulator-5560 reverse "tcp:$PORT" "tcp:$PORT" >/dev/null
  # The debug test build is signed differently: remove the release app first.
  "$ADB" -s emulator-5560 uninstall de.themorpheus.morphhealth.local >/dev/null 2>&1 || true
  flutter test integration_test -d emulator-5560 \
    --dart-define=FOOD_API_BASE_URL="$BASE" --dart-define=FOOD_API_USER_AGENT="$UA"
  "$ADB" -s emulator-5560 uninstall de.themorpheus.morphhealth.local >/dev/null 2>&1 || true
  if [[ -f "$APK" ]]; then
    "$ADB" -s emulator-5560 install "$APK" >/dev/null && echo "ok   release APK reinstalled"
  fi
fi

echo
echo "All checks passed."
