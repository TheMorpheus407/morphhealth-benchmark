#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$TASK_ROOT/app"
flutter pub get --enforce-lockfile
flutter analyze
flutter test
cd "$TASK_ROOT"
python3 scripts/check_cli.py
