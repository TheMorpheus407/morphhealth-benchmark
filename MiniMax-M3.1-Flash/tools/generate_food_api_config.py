#!/usr/bin/env python3
"""Generates the food API configuration of MorphHealth from ENVIRONMENT.json.

The origin and the user agent of the read only Open Food Facts endpoint are
not hard coded in the product code. They are read from the (read only)
environment manifest and written into a generated Dart file that both the
Flutter app and the `mh` CLI use.

Usage:
    python3 tools/generate_food_api_config.py [ENVIRONMENT.json] [target.dart]
"""

from __future__ import annotations

import json
import pathlib
import sys

DEFAULT_ENV = pathlib.Path(__file__).resolve().parent.parent / "ENVIRONMENT.json"
DEFAULT_TARGET = (
    pathlib.Path(__file__).resolve().parent.parent
    / "app"
    / "packages"
    / "morphhealth_core"
    / "lib"
    / "src"
    / "generated"
    / "food_api_config.dart"
)

TEMPLATE = """// GENERATED FILE - DO NOT EDIT.
//
// Created by tools/generate_food_api_config.py from ENVIRONMENT.json.
// The values describe the read only Open Food Facts endpoint of this
// environment. They can be overridden per installation in the app settings
// and with `--food-base-url` / `--food-user-agent` in the `mh` CLI.

/// Base URL of the Open Food Facts endpoint (read only contract of P08).
const String kFoodApiBaseUrl = {base_url};

/// User agent sent with every request.
const String kFoodApiUserAgent = {user_agent};
"""


def main() -> int:
    env_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_ENV
    target = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_TARGET

    with env_path.open("r", encoding="utf-8") as handle:
        env = json.load(handle)

    base_url = env["food_api_base_url"]
    user_agent = env["food_api_user_agent"]

    target.parent.mkdir(parents=True, exist_ok=True)
    content = TEMPLATE.format(
        base_url=json.dumps(base_url),
        user_agent=json.dumps(user_agent),
    )
    target.write_text(content, encoding="utf-8")
    print(f"wrote {target} (base_url={base_url})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
