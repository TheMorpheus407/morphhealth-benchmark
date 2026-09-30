#!/usr/bin/env bash
# Builds the MorphHealth release APK (artifacts/morphhealth.apk) and the
# native mh maintenance binary (artifacts/mh-linux-x64).
#
# Food database origin and User-Agent are taken from ENVIRONMENT.json
# (food_api_base_url, food_api_user_agent) unless FOOD_API_BASE_URL /
# FOOD_API_USER_AGENT are set; without either, the product defaults
# (https://world.openfoodfacts.org) are used.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/app"
ENV_FILE="$ROOT/ENVIRONMENT.json"
ARTIFACTS="$ROOT/artifacts"

env_value() {
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get(sys.argv[2]) or "")' "$ENV_FILE" "$1"
}

FOOD_BASE_URL="${FOOD_API_BASE_URL:-}"
FOOD_USER_AGENT="${FOOD_API_USER_AGENT:-}"
if [[ -f "$ENV_FILE" ]]; then
  [[ -n "$FOOD_BASE_URL" ]] || FOOD_BASE_URL="$(env_value food_api_base_url)"
  [[ -n "$FOOD_USER_AGENT" ]] || FOOD_USER_AGENT="$(env_value food_api_user_agent)"
fi
FOOD_BASE_URL="${FOOD_BASE_URL:-https://world.openfoodfacts.org}"
FOOD_USER_AGENT="${FOOD_USER_AGENT:-MorphHealth/1.0 (de.themorpheus.morphhealth.local)}"

echo "==> Food database: $FOOD_BASE_URL"
echo "==> User-Agent:    $FOOD_USER_AGENT"

# Local release signing key, generated once and kept in app/android/signing
# (not a store key; see README.md "Signatur").
SIGNING_DIR="$APP/android/signing"
KEY_PROPERTIES="$APP/android/key.properties"
if [[ ! -f "$KEY_PROPERTIES" ]]; then
  echo "==> Creating local release signing key"
  mkdir -p "$SIGNING_DIR"
  PASS="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)"
  keytool -genkeypair \
    -keystore "$SIGNING_DIR/morphhealth-release.jks" -storetype PKCS12 \
    -alias morphhealth -keyalg RSA -keysize 3072 -validity 10000 \
    -storepass "$PASS" -keypass "$PASS" \
    -dname "CN=MorphHealth local build, O=Bootstrap Academy, C=DE" >/dev/null
  cat > "$KEY_PROPERTIES" <<EOF
storeFile=signing/morphhealth-release.jks
storePassword=$PASS
keyAlias=morphhealth
keyPassword=$PASS
EOF
  chmod 600 "$KEY_PROPERTIES" "$SIGNING_DIR/morphhealth-release.jks"
fi

cd "$APP"
echo "==> Resolving locked dependencies"
flutter pub get --enforce-lockfile

echo "==> Building release APK"
flutter build apk --release \
  --split-debug-info="$APP/build/debug-info" \
  --dart-define=FOOD_API_BASE_URL="$FOOD_BASE_URL" \
  --dart-define=FOOD_API_USER_AGENT="$FOOD_USER_AGENT"

mkdir -p "$ARTIFACTS"
cp build/app/outputs/flutter-apk/app-release.apk "$ARTIFACTS/morphhealth.apk"

echo "==> Compiling mh maintenance binary"
dart compile exe bin/mh.dart -o "$ARTIFACTS/mh-linux-x64"

(cd "$ARTIFACTS" && sha256sum morphhealth.apk mh-linux-x64 > SHA256SUMS)
echo "==> Done:"
ls -l "$ARTIFACTS"
