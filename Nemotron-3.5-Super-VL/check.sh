#!/bin/sh
# check.sh — Statische Analyse und eigene Tests ausfuehren (SPEC P12).
set -e

DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR/app"

echo "[check.sh] flutter analyze..."
flutter analyze

echo "[check.sh] flutter test..."
flutter test

echo "Alle Prufungen bestanden."