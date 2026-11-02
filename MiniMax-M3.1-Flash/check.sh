#!/usr/bin/env bash
#
# Static analysis and the own test suites of MorphHealth.
#
#   ./check.sh
#
# Runs the analyzer over the shared core and the Flutter app, the unit and
# widget tests and a smoke test of the maintenance CLI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"
CORE="$APP/packages/morphhealth_core"

FAILURES=0

step() {
  echo
  echo "==> $1"
}

fail() {
  echo "FAILED: $1" >&2
  FAILURES=$((FAILURES + 1))
}

step "food API configuration is up to date"
python3 "$ROOT/tools/generate_food_api_config.py"

step "resolving dependencies"
(cd "$CORE" && dart pub get)
(cd "$APP" && flutter pub get)

step "analyzing the shared core"
if (cd "$CORE" && dart analyze); then
  echo "core: no issues"
else
  fail "dart analyze (core)"
fi

step "analyzing the Flutter app"
if (cd "$APP" && flutter analyze); then
  echo "app: no issues"
else
  fail "flutter analyze (app)"
fi

step "unit tests of the shared core"
if (cd "$CORE" && dart test); then
  echo "core tests: ok"
else
  fail "dart test (core)"
fi

step "widget tests of the app"
if (cd "$APP" && flutter test); then
  echo "app tests: ok"
else
  fail "flutter test (app)"
fi

step "smoke test of the maintenance CLI"
TMP="$(mktemp -d)"
# The temporary directory is removed with Python, because "rm" is not part of
# the documented tool chain of the environment.
trap 'python3 -c "import shutil, sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$TMP"' EXIT
head -c 32 /dev/urandom > "$TMP/key.bin"

# 1. The plain operations answer with one line each.
OUT="$(
  printf '%s\n' \
    '{"request_id":1,"op":"describe"}' \
    '{"request_id":2,"op":"nutrition.day","date":"2026-01-01"}' \
    '{"request_id":3,"op":"cycle.forecast","on":"2026-01-01"}' \
    | "$ROOT/mh" --data-dir "$TMP/data" --key-file "$TMP/key.bin" 2>/dev/null
)"
if [ "$(printf '%s\n' "$OUT" | wc -l)" = "3" ] &&
   printf '%s\n' "$OUT" | grep -q '"ok":true'; then
  echo "mh: 3 of 3 operations answered"
else
  fail "mh smoke test"
  printf '%s\n' "$OUT" >&2
fi

# 2. The export needs the acknowledgement of the caller.
printf '%s\n' \
  '{"request_id":10,"op":"portable.export"}' \
  '{"request_id":11,"op":"portable.export","ack_plaintext":true}' \
  | "$ROOT/mh" --data-dir "$TMP/data" --key-file "$TMP/key.bin" 2>/dev/null \
  > "$TMP/export.jsonl"

if python3 - "$TMP/export.jsonl" "$TMP/document.json" <<'PY'
import json
import sys

lines = [json.loads(line) for line in open(sys.argv[1]) if line.strip()]
if len(lines) != 2:
    sys.exit(1)
if lines[0].get('ok') is not False:
    sys.exit(1)
if lines[0].get('error', {}).get('code') != 'ack_required':
    sys.exit(1)
if lines[1].get('ok') is not True:
    sys.exit(1)
document = lines[1]['data']['document']
if document.get('format') != 'morphhealth.portable':
    sys.exit(1)
with open(sys.argv[2], 'w') as handle:
    json.dump(document, handle)
PY
then
  echo "mh: portable.export demands the acknowledgement"
else
  fail "mh portable.export guard"
fi

# 3. The import needs the confirmation and then replaces the data set.
python3 - "$TMP/document.json" "$TMP/import.jsonl" <<'PY'
import json
import sys

with open(sys.argv[1]) as handle:
    document = json.load(handle)
requests = [
    {'request_id': 20, 'op': 'portable.import', 'document': document},
    {
        'request_id': 21,
        'op': 'portable.import',
        'document': document,
        'confirm_replace': True,
    },
]
with open(sys.argv[2], 'w') as handle:
    for request in requests:
        handle.write(json.dumps(request) + '\n')
PY

OUT="$("$ROOT/mh" --data-dir "$TMP/data" --key-file "$TMP/key.bin" \
  < "$TMP/import.jsonl" 2>/dev/null)"
printf '%s\n' "$OUT" > "$TMP/import.out"
if python3 - "$TMP/import.out" <<'PY'
import json
import sys

with open(sys.argv[1]) as handle:
    lines = [json.loads(line) for line in handle if line.strip()]
if len(lines) != 2:
    raise SystemExit(1)
if lines[0].get('ok') is not False:
    raise SystemExit(1)
if lines[0].get('error', {}).get('code') != 'confirm_required':
    raise SystemExit(1)
if lines[1].get('ok') is not True:
    raise SystemExit(1)
PY
then
  echo "mh: portable.import demands the confirmation and replaces the data set"
else
  fail "mh portable.import guard"
  printf '%s\n' "$OUT" >&2
fi

if [ "$FAILURES" = "0" ]; then
  echo
  echo "all checks passed."
else
  echo
  echo "$FAILURES check(s) failed." >&2
  exit 1
fi
