#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-/home/morpheus/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

echo "=== [1/4] Static analysis (flutter analyze) ==="
(
  cd "$ROOT_DIR/app"
  flutter analyze
)

echo "=== [2/4] Automated unit, crypto, 10k-entry performance & widget tests ==="
(
  cd "$ROOT_DIR/app"
  flutter test
)

echo "=== [3/4] Compiling & verifying ./mh JSON-Lines maintenance CLI ==="
mkdir -p "$ROOT_DIR/artifacts"
(
  cd "$ROOT_DIR/app"
  dart compile exe bin/mh.dart -o "$ROOT_DIR/artifacts/mh-bin"
)
chmod +x "$ROOT_DIR/mh" "$ROOT_DIR/artifacts/mh-bin"

WORK_TMP="$(mktemp -d "$ROOT_DIR/.check_mh_XXXXXX")"
cleanup() {
  rm -rf "$WORK_TMP"
}
trap cleanup EXIT

mkdir -p "$WORK_TMP/data"
head -c 32 /dev/urandom > "$WORK_TMP/master.key"

python3 - "$ROOT_DIR" "$WORK_TMP" <<'PY'
import json, pathlib, subprocess, sys

root = pathlib.Path(sys.argv[1])
tmp = pathlib.Path(sys.argv[2])
mh = str(root / "mh")
data_dir = str(tmp / "data")
key_file = str(tmp / "master.key")

# 1. Reject key-file inside data-dir
inside_key = tmp / "data" / "illegal.key"
inside_key.write_bytes(b"0" * 32)
bad = subprocess.run(
    [mh, "--data-dir", data_dir, "--key-file", str(inside_key)],
    input="",
    capture_output=True,
    text=True,
)
assert bad.returncode != 0, "Expected non-zero exit when key-file is inside data-dir"
inside_key.unlink()

# 2. Full interactive JSON-Lines session
proc = subprocess.Popen(
    [mh, "--data-dir", data_dir, "--key-file", key_file, "--now", "2026-09-23T10:00:00+02:00"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)

def call(req):
    proc.stdin.write(json.dumps(req) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    assert line, "Unexpected EOF on stdout"
    return json.loads(line)

desc = call({"request_id": "req-1", "op": "describe"})
assert desc["ok"] is True and desc["request_id"] == "req-1"
example_doc = desc["data"]["example_portable_document"]
assert len(desc["data"]["portable_format"]["nutrients_supported"]) == 31

imp = call({"request_id": 2, "op": "portable.import", "document": example_doc, "confirm_replace": True})
assert imp["ok"] is True and imp["data"]["replaced"] is True

exp = call({"request_id": "req-3", "op": "portable.export", "ack_plaintext": True})
assert exp["ok"] is True and exp["data"]["format"] == "morphhealth.portable"

nut = call({"request_id": "req-4", "op": "nutrition.day", "date": "2026-09-23"})
assert nut["ok"] is True
assert abs(nut["data"]["nutrients"]["calories_kcal"] - 279.0) < 0.01
assert nut["data"]["water_ml"] == 330.0
assert nut["data"]["total_caffeine_mg"] == 65.0

cyc = call({"request_id": "req-5", "op": "cycle.forecast", "on": "2026-09-23"})
assert cyc["ok"] is True and cyc["data"]["predicted_next_start"] == "2026-09-24"

srch = call({"request_id": "req-6", "op": "food.search", "q": "haferflocken", "page": 1})
assert srch["ok"] is True and len(srch["data"]["items"]) > 0

lkp = call({"request_id": "req-7", "op": "food.lookup", "barcode": "5411188112709"})
assert lkp["ok"] is True and lkp["data"]["item"]["barcode"] == "5411188112709"

not_found = call({"request_id": "req-8", "op": "food.lookup", "barcode": "9780000000002"})
assert not_found["ok"] is False and not_found["error"]["code"] == "PRODUCT_NOT_FOUND"

proc.stdin.close()
assert proc.wait() == 0, f"Non-zero exit on EOF: {proc.stderr.read()}"

# Ensure no plaintext files exist in data_dir
vault_files = [p.name for p in (tmp / "data").iterdir()]
assert vault_files == ["vault.mhv1"], f"Unexpected files in data-dir: {vault_files}"
raw_vault = (tmp / "data" / "vault.mhv1").read_bytes()
assert raw_vault[:8] == b"MHVAULT1"
assert b"Haferflocken" not in raw_vault
print("Verified ./mh JSON-Lines RPC, Open Food Facts contract, and encrypted vault on disk.")
PY

echo "=== [4/4] Checking APK artifact (if built) ==="
if [[ -f "$ROOT_DIR/artifacts/morphhealth.apk" ]]; then
  python3 - "$ROOT_DIR/artifacts/morphhealth.apk" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "r") as zf:
    assert "lib/x86_64/libapp.so" in zf.namelist()
print("APK artifact verified: artifacts/morphhealth.apk")
PY
else
  echo "Note: artifacts/morphhealth.apk not built yet (run ./build.sh)."
fi

echo "All checks passed."
