#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/app"
flutter pub get --offline || flutter pub get
flutter build apk --release --target-platform android-x64
mkdir -p ../artifacts
cp build/app/outputs/flutter-apk/app-release.apk ../artifacts/morphhealth.apk
(cd ../mh_tool && dart pub get --offline && dart compile exe lib/main.dart -o build/mh)
echo "build ok: artifacts/morphhealth.apk"
