#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-/home/morpheus/Android/Sdk}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

echo "=== [1/4] Static Analysis (flutter analyze) ==="
(cd "$ROOT_DIR/app" && flutter analyze)

echo "=== [2/4] Automated Unit, Widget & 10k Performance Tests (flutter test) ==="
(cd "$ROOT_DIR/app" && flutter test)

echo "=== [3/4] End-to-End Verification of ./mh JSON-Lines Interface ==="
python3 - "$ROOT_DIR" <<'PY'
import json
import os
import subprocess
import sys
import tempfile

root = sys.argv[1]
mh_bin = os.path.join(root, "mh")

with tempfile.TemporaryDirectory(dir=root) as tmp:
    data_dir = os.path.join(tmp, "vault_data")
    key_file = os.path.join(tmp, "master.key")
    with open(key_file, "wb") as f:
        f.write(os.urandom(32))

    # 1. Verify rejection of key-file inside data-dir
    os.makedirs(data_dir, exist_ok=True)
    bad_key = os.path.join(data_dir, "inside.key")
    with open(bad_key, "wb") as f:
        f.write(os.urandom(32))
    bad_proc = subprocess.run(
        [mh_bin, "--data-dir", data_dir, "--key-file", bad_key],
        input="",
        text=True,
        capture_output=True,
    )
    assert bad_proc.returncode != 0, "Expected key inside data-dir to be rejected"
    os.remove(bad_key)

    # 2. Run full JSON-Lines session across all 7 ops
    proc = subprocess.Popen(
        [
            mh_bin,
            "--data-dir",
            data_dir,
            "--key-file",
            key_file,
            "--now",
            "2026-10-15T10:00:00+02:00",
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    def send(payload):
        proc.stdin.write(json.dumps(payload) + "\n")
        proc.stdin.flush()
        line = proc.stdout.readline()
        assert line, "Unexpected EOF from mh"
        return json.loads(line)

    # describe
    r_desc = send({"request_id": "req-1", "op": "describe"})
    assert r_desc["request_id"] == "req-1" and r_desc["ok"] is True
    assert len(r_desc["data"]["nutrients"]) == 31
    example_doc = r_desc["data"]["example_document"]

    # portable.export without ack_plaintext must fail
    r_exp_bad = send({"request_id": "req-2", "op": "portable.export"})
    assert r_exp_bad["ok"] is False

    # portable.import
    r_imp = send(
        {
            "request_id": "req-3",
            "op": "portable.import",
            "document": example_doc,
            "confirm_replace": True,
        }
    )
    assert r_imp["ok"] is True
    assert r_imp["data"]["replaced"] is True

    # nutrition.day
    r_nut = send(
        {"request_id": "req-4", "op": "nutrition.day", "date": "2026-10-15"}
    )
    assert r_nut["ok"] is True
    assert abs(r_nut["data"]["calories_kcal"] - 279.0) < 0.1
    assert abs(r_nut["data"]["water_ml"] - 800.0) < 0.1
    assert abs(r_nut["data"]["caffeine_mg"] - 80.0) < 0.1

    # cycle.forecast
    r_cyc = send(
        {"request_id": "req-5", "op": "cycle.forecast", "on": "2026-10-15"}
    )
    assert r_cyc["ok"] is True
    assert r_cyc["data"]["expected_start_date"] == "2026-10-31"
    assert "28, 29, 28" in r_cyc["data"]["explanation"]["de"]

    # food.search
    r_srch = send(
        {"request_id": "req-6", "op": "food.search", "q": "Haferflocken", "page": 1}
    )
    assert r_srch["ok"] is True
    assert len(r_srch["data"]["products"]) > 0

    # food.lookup
    r_lkp = send(
        {"request_id": "req-7", "op": "food.lookup", "barcode": "5411188112709"}
    )
    assert r_lkp["ok"] is True
    assert r_lkp["data"]["nutrients_per_100g"]["calcium_mg"] == 120.0

    # portable.export
    r_exp = send(
        {"request_id": "req-8", "op": "portable.export", "ack_plaintext": True}
    )
    assert r_exp["ok"] is True
    assert r_exp["data"]["schema_version"] == "morphhealth.portable.v1"

    proc.stdin.close()
    rc = proc.wait()
    assert rc == 0, f"mh exited with code {rc}"

    # 3. Verify vault file on disk is encrypted (starts with MHV1 magic, no plaintext)
    vault_path = os.path.join(data_dir, "vault.mhv")
    with open(vault_path, "rb") as vf:
        raw = vf.read()
    assert raw[:4] == b"MHV1", "Vault file missing MHV1 magic header"
    assert b"Haferflocken" not in raw, "Plaintext leaked in encrypted vault"

    # 4. Verify wrong 32-byte key fails to open existing vault
    wrong_key = os.path.join(tmp, "wrong.key")
    with open(wrong_key, "wb") as f:
        f.write(os.urandom(32))
    wrong_proc = subprocess.run(
        [mh_bin, "--data-dir", data_dir, "--key-file", wrong_key],
        input="",
        text=True,
        capture_output=True,
    )
    assert wrong_proc.returncode != 0, "Expected wrong key to fail decryption"

print("All ./mh protocol and encryption checks passed!")
PY

echo "=== [4/4] Checking Release APK Artifact (if present) ==="
if [[ -f "$ROOT_DIR/artifacts/morphhealth.apk" ]]; then
  unzip -l "$ROOT_DIR/artifacts/morphhealth.apk" | grep "lib/x86_64/libapp.so"
  echo "Verified x86_64 native library in artifacts/morphhealth.apk"
else
  echo "Note: artifacts/morphhealth.apk not built yet (run ./build.sh first)."
fi

echo "=== ALL CHECKS PASSED ==="
