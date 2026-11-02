#!/usr/bin/env bash
# Small helper for driving the app on the reference emulator.
set -euo pipefail
ADB=/home/morpheus/Android/Sdk/platform-tools/adb
SERIAL=emulator-5560
PKG=de.themorpheus.morphhealth.local

case "${1:-}" in
  tap)    $ADB -s "$SERIAL" shell input tap "$2" "$3" ;;
  swipe)  $ADB -s "$SERIAL" shell input swipe "$2" "$3" "$4" "$5" "${6:-300}" ;;
  text)   $ADB -s "$SERIAL" shell input text "$2" ;;
  key)    $ADB -s "$SERIAL" shell input keyevent "$2" ;;
  shot)   $ADB -s "$SERIAL" exec-out screencap -p > "${2:-/tmp/mh_shot.png}"; echo "${2:-/tmp/mh_shot.png}" ;;
  start)  $ADB -s "$SERIAL" shell am force-stop "$PKG"; $ADB -s "$SERIAL" shell am start -n "$PKG/.MainActivity" >/dev/null; sleep "${2:-6}" ;;
  stop)   $ADB -s "$SERIAL" shell am force-stop "$PKG" ;;
  clear)  $ADB -s "$SERIAL" shell pm clear "$PKG" ;;
  log)    $ADB -s "$SERIAL" logcat -d -t "${2:-200}" | grep -iE "flutter|morphhealth|AndroidRuntime|FATAL" | tail -"${3:-30}" ;;
  reverseadb) $ADB -s "$SERIAL" reverse tcp:8788 tcp:8788 ;;
  *) echo "usage: $0 {tap|swipe|text|key|shot|start|stop|clear|log|reverseadb} ..." >&2; exit 2 ;;
esac
