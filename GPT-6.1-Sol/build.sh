#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT"
export PUB_CACHE="$ROOT/.cache/pub"
export XDG_CONFIG_HOME="$ROOT/.cache/config"
export GRADLE_USER_HOME="$ROOT/.cache/gradle"
mkdir -p "$ROOT/.cache" artifacts .signing
readarray -t CONFIG < <(python3 - "$ROOT/ENVIRONMENT.json" <<'PY'
import json,sys,pathlib
e=json.load(open(sys.argv[1]))
print(pathlib.Path(e['toolchain']['jdk_used_by_flutter_gradle']['java_binary']).parent.parent)
print(e['toolchain']['android_sdk_path'])
pathlib.Path('.cache/food-build.json').write_text(json.dumps({
  'FOOD_BASE_URL':e['food_api_base_url'],
  'FOOD_USER_AGENT':e['food_api_user_agent'],
}))
PY
)
export JAVA_HOME="${CONFIG[0]}"
export ANDROID_HOME="${CONFIG[1]}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export MH_SIGN_KEY="$ROOT/.signing/morphhealth.jks"
if [[ ! -f .signing/password ]]; then
  python3 - <<'PY'
import secrets,pathlib,os
p=pathlib.Path('.signing/password')
p.write_text(secrets.token_hex(32)+'\n')
os.chmod(p,0o600)
PY
fi
read -r MH_SIGN_PASSWORD < .signing/password
export MH_SIGN_PASSWORD
if [[ ! -f "$MH_SIGN_KEY" ]]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$MH_SIGN_KEY" -alias morphhealth \
    -storepass:env MH_SIGN_PASSWORD -keypass:env MH_SIGN_PASSWORD \
    -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=MorphHealth Local Build" >&2
  chmod 600 "$MH_SIGN_KEY"
fi
flutter pub get --enforce-lockfile --directory app
(
  cd app
  flutter build apk --release --target-platform android-arm64,android-x64 \
    --dart-define-from-file="$ROOT/.cache/food-build.json" --no-pub
  dart compile exe tool/mh.dart -o "$ROOT/artifacts/mh-core"
)
cp app/build/app/outputs/flutter-apk/app-release.apk artifacts/morphhealth.apk
sha256sum artifacts/morphhealth.apk > artifacts/morphhealth.apk.sha256
printf 'APK: %s\n' "$ROOT/artifacts/morphhealth.apk"
