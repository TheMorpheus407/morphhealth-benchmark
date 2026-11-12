#!/bin/sh
# build.sh — Kompletter Build von MorphHealth (SPEC P09).
# Erzeugt app/, artifacts/morphhealth.apk und stellt sicher, dass mh ausfuehrbar ist.
set -e

DIR=$(cd "$(dirname "$0")" && pwd)

echo "[build.sh] Flutter-Abhaengigkeiten auflosen..."
cd "$DIR/app"
flutter pub get

echo "[build.sh] Release-APK bauen (x86_64)..."
flutter build apk --release --target-platform android-x64

echo "[build.sh] APK kopieren..."
mkdir -p "$DIR/artifacts"
cp "$DIR/app/build/app/outputs/flutter-apk/app-release.apk" "$DIR/artifacts/morphhealth.apk"

chmod +x "$DIR/mh"

echo "Fertig: $DIR/artifacts/morphhealth.apk ($(stat -c %s "$DIR/artifacts/morphhealth.apk") Byte)"