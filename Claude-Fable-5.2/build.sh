#!/usr/bin/env bash
# Baut MorphHealth aus den Quellen.
#
#   artifacts/morphhealth.apk   Release-APK für Android (arm64-v8a und x86_64)
#   artifacts/mh-linux-x64      Wartungszugang `mh` als eigenständiges Programm
#   artifacts/build-info.txt    womit und wofür gebaut wurde, Prüfsummen
#
# Aufruf:  ./build.sh [--mh-only] [--apk-only] [--x86_64-only] [--product]
#
#   --mh-only       nur den Wartungszugang bauen
#   --apk-only      nur die APK bauen
#   --x86_64-only   APK nur für x86_64 (kleiner, schnellerer Build)
#   --product       die Produktwerte der App für Adresse und Kennung des
#                   Lebensmitteldienstes verwenden
#                   (https://world.openfoodfacts.org); ENVIRONMENT.json wird
#                   dafür übergangen
#
# Die Adresse des Lebensmitteldienstes und die Kennung (User-Agent) stammen
# aus ENVIRONMENT.json (food_api_base_url, food_api_user_agent) und werden der
# App beim Bauen mitgegeben. In der App lässt sich die Adresse später in den
# Einstellungen ändern. Verwendet wird die installierte Toolchain (flutter,
# dart, JDK, Android SDK); die Abhängigkeiten sind in app/pubspec.lock gesperrt.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"
CORE="$APP/packages/morphhealth_core"
OUT="$ROOT/artifacts"
ENVIRONMENT="$ROOT/ENVIRONMENT.json"
KEYSTORE="$APP/android/app/morphhealth-local.jks"

build_mh=1
build_apk=1
platforms="android-arm64,android-x64"
use_environment=1
for arg in "$@"; do
  case "$arg" in
    --mh-only) build_apk=0 ;;
    --apk-only) build_mh=0 ;;
    --x86_64-only) platforms="android-x64" ;;
    --product) use_environment=0 ;;
    -h | --help)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "build.sh: unbekannte Option: $arg" >&2
      exit 64
      ;;
  esac
done

say() { printf '\n== %s\n' "$*" >&2; }

for tool in flutter dart; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "build.sh: $tool fehlt im PATH" >&2
    exit 69
  }
done

# Liest einen Zeichenkettenwert der obersten Ebene aus ENVIRONMENT.json.
environment_value() {
  [ "$use_environment" = 1 ] && [ -f "$ENVIRONMENT" ] || return 0
  python3 -I -c '
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8")).get(sys.argv[2], "")
print(value if isinstance(value, str) else "")
' "$ENVIRONMENT" "$1"
}

food_base_url="$(environment_value food_api_base_url)"
food_user_agent="$(environment_value food_api_user_agent)"

mkdir -p "$OUT"

say "Abhängigkeiten nach app/pubspec.lock"
(cd "$APP" && flutter pub get --enforce-lockfile >&2)

if [ "$build_mh" = 1 ]; then
  say "Wartungszugang mh"
  # Erst neben das Ziel bauen und dann umbenennen: ein laufendes mh behält
  # sein altes Programm, und ein abgebrochener Build hinterlässt kein halbes.
  tmp="$OUT/.mh-linux-x64.$$"
  trap 'rm -f "$tmp"' EXIT
  (cd "$CORE" && dart compile exe bin/mh.dart -o "$tmp" >&2)
  chmod 755 "$tmp"
  mv -f "$tmp" "$OUT/mh-linux-x64"
  trap - EXIT
fi

if [ "$build_apk" = 1 ]; then
  if [ ! -f "$KEYSTORE" ]; then
    say "Signierschlüssel des lokalen Builds anlegen"
    # Kein Geheimnis: Schlüssel und Passwort gehören zum Projekt (SECURITY.md).
    keytool -genkeypair -keystore "$KEYSTORE" -storetype PKCS12 \
      -storepass morphhealth-local -keypass morphhealth-local \
      -alias morphhealth-local -keyalg RSA -keysize 3072 -validity 10950 \
      -dname "CN=MorphHealth local build, O=MorphHealth, C=DE" >&2
  fi

  defines=()
  if [ -n "$food_base_url" ]; then
    defines+=("--dart-define=FOOD_API_BASE_URL=$food_base_url")
  fi
  if [ -n "$food_user_agent" ]; then
    defines+=("--dart-define=FOOD_API_USER_AGENT=$food_user_agent")
  fi

  say "Release-APK ($platforms)"
  (cd "$APP" && flutter build apk --release --no-pub \
    --target-platform "$platforms" "${defines[@]}" >&2)
  cp -f "$APP/build/app/outputs/flutter-apk/app-release.apk" \
    "$OUT/morphhealth.apk"
fi

# Der Baubericht gehört zur APK; ein reiner mh-Build lässt ihn stehen.
if [ "$build_apk" = 1 ]; then
  {
    echo "MorphHealth – Build vom $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Flutter: $(flutter --version 2>/dev/null | head -n 1)"
    echo "Dart: $(dart --version 2>&1 | head -n 1)"
    echo "APK-Plattformen: $platforms"
    echo "Lebensmitteldienst der APK: ${food_base_url:-https://world.openfoodfacts.org (Produktwert)}"
    echo "Kennung der APK: ${food_user_agent:-Produktwert der App}"
    echo "SHA-256:"
    (cd "$OUT" && for f in morphhealth.apk mh-linux-x64; do
      if [ -f "$f" ]; then sha256sum "$f"; fi
    done)
  } >"$OUT/build-info.txt"
  say "Fertig"
  cat "$OUT/build-info.txt" >&2
else
  say "Fertig"
  (cd "$OUT" && sha256sum mh-linux-x64 >&2)
fi
