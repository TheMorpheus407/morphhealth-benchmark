#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-/home/morpheus/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

echo "[1/3] Compiling local maintenance CLI (./mh)..."
mkdir -p "$ROOT_DIR/app/build/mh_cli"
(
  cd "$ROOT_DIR/app"
  flutter pub get
  dart compile exe bin/mh.dart -o "$ROOT_DIR/app/build/mh_cli/mh_bin"
)
chmod +x "$ROOT_DIR/mh"

echo "[2/3] Building Android Release APK (with x86_64 support)..."
(
  cd "$ROOT_DIR/app"
  flutter build apk --release
)

echo "[3/3] Copying release artifact to artifacts/morphhealth.apk..."
mkdir -p "$ROOT_DIR/artifacts"
cp -f "$ROOT_DIR/app/build/app/outputs/flutter-apk/app-release.apk" "$ROOT_DIR/artifacts/morphhealth.apk"

ls -lh "$ROOT_DIR/artifacts/morphhealth.apk"
echo "Build complete: $ROOT_DIR/artifacts/morphhealth.apk"
