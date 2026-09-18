#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in run|--verify|--build|--debug|--logs|--telemetry) ;; *) echo "Usage: $0 [--build|--verify|--debug|--logs|--telemetry]" >&2; exit 2;; esac
APP_BUNDLE="$ROOT_DIR/.build/xcode/Build/Products/Debug/DaystingIRC.app"
if [[ "$MODE" != --build ]]; then pkill -x DaystingIRC >/dev/null 2>&1 || true; fi
xcodebuild -project "$ROOT_DIR/DaystingIRC.xcodeproj" -scheme DaystingIRC-macOS -configuration Debug -destination 'platform=macOS' -derivedDataPath "$ROOT_DIR/.build/xcode" CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES "OTHER_SWIFT_FLAGS=${DAYSTING_SWIFT_FLAGS:-}" build
case "$MODE" in
  --build) exit 0 ;;
  --debug) exec lldb -- "$APP_BUNDLE/Contents/MacOS/DaystingIRC" ;;
esac
/usr/bin/open -n "$APP_BUNDLE"
case "$MODE" in
  --verify) sleep 2; pgrep -x DaystingIRC >/dev/null ;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "DaystingIRC"' ;;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.daysting.ircclient"' ;;
esac
