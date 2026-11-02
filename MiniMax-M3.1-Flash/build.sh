#!/usr/bin/env bash
#
# Builds MorphHealth: the Android release APK and the local maintenance CLI.
#
#   ./build.sh              release APK + mh
#   ./build.sh --apk        only the release APK
#   ./build.sh --mh         only the maintenance CLI
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"
CORE="$APP/packages/morphhealth_core"
ARTIFACTS="$ROOT/artifacts"

DO_APK=1
DO_MH=1
for arg in "$@"; do
  case "$arg" in
    --apk) DO_MH=0 ;;
    --mh) DO_APK=0 ;;
    *) echo "build.sh: unknown argument '$arg'" >&2; exit 2 ;;
  esac
done

echo "==> 1/4 food API configuration from ENVIRONMENT.json"
python3 "$ROOT/tools/generate_food_api_config.py"

echo "==> 2/4 resolving dependencies"
(cd "$CORE" && dart pub get)
(cd "$APP" && flutter pub get)

if [ "$DO_MH" = "1" ]; then
  echo "==> 3/4 building the maintenance CLI"
  mkdir -p "$ROOT/build"
  (cd "$CORE" && dart compile exe bin/mh.dart -o "$ROOT/build/mh")
  echo "    build/mh"
else
  echo "==> 3/4 skipping the maintenance CLI"
fi

if [ "$DO_APK" = "1" ]; then
  echo "==> 4/4 building the release APK"
  (cd "$APP" && flutter build apk --release)
  mkdir -p "$ARTIFACTS"
  cp "$APP/build/app/outputs/flutter-apk/app-release.apk" "$ARTIFACTS/morphhealth.apk"
  echo "    artifacts/morphhealth.apk"
else
  echo "==> 4/4 skipping the release APK"
fi

echo
echo "done."
ls -l "$ARTIFACTS/morphhealth.apk" 2>/dev/null || true
ls -l "$ROOT/build/mh" 2>/dev/null || true
