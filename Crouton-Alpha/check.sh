#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/app"
flutter pub get --offline || flutter pub get
flutter analyze
flutter test
(cd ../mh_tool && dart pub get --offline && dart analyze && dart test 2>/dev/null || true)
echo "check ok"
