#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT"
export PUB_CACHE="$ROOT/.cache/pub"
export XDG_CONFIG_HOME="$ROOT/.cache/config"
flutter pub get --enforce-lockfile --directory app
dart format --output=none --set-exit-if-changed app/lib app/tool app/test
flutter analyze --no-pub app
(
  cd app
  flutter test --no-pub
)
python3 scripts/check_cli.py
if [[ "${1:-}" == "--device" ]]; then
  ./scripts/check_device.sh
fi
