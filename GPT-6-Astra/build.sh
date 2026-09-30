#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$TASK_ROOT"
mkdir -p artifacts
python3 - <<'PY'
import json
from pathlib import Path
e=json.loads(Path('ENVIRONMENT.json').read_text())
Path('app/build-config.json').write_text(json.dumps({'FOOD_API_BASE_URL':e['food_api_base_url'],'FOOD_API_USER_AGENT':e['food_api_user_agent']}))
PY
cd app
flutter pub get --enforce-lockfile
flutter build apk --release --target-platform android-arm64,android-x64 --dart-define-from-file=build-config.json
cp build/app/outputs/flutter-apk/app-release.apk ../artifacts/morphhealth.apk
cd ..
sha256sum artifacts/morphhealth.apk > artifacts/morphhealth.apk.sha256
