#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="FinderTools"
BUNDLE_ID="com.wheat.FinderTools"
EXTENSION_ID="com.wheat.FinderTools.FinderToolsExtension"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
BUILT_APP="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
BUILT_EXTENSION="$BUILT_APP/Contents/PlugIns/FinderToolsExtension.appex"
INSTALLED_APP="/Applications/$APP_NAME.app"
INSTALLED_EXTENSION="$INSTALLED_APP/Contents/PlugIns/FinderToolsExtension.appex"
APP_BINARY="$INSTALLED_APP/Contents/MacOS/$APP_NAME"

if [[ "$DERIVED_DATA" != "$ROOT_DIR/.build/DerivedData" ]]; then
  echo "Refusing to clean an unexpected cache path: $DERIVED_DATA" >&2
  exit 1
fi

if [[ "$INSTALLED_APP" != "/Applications/FinderTools.app" ]]; then
  echo "Refusing to replace an unexpected app path: $INSTALLED_APP" >&2
  exit 1
fi

pkill -x FinderToolsExtension >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [[ -e "$INSTALLED_EXTENSION" ]]; then
  pluginkit -r "$INSTALLED_EXTENSION" >/dev/null 2>&1 || true
fi

rm -rf -- "$INSTALLED_APP"
rm -rf -- "$DERIVED_DATA"

xcodebuild \
  -project "$ROOT_DIR/FinderTools.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  build

ditto "$BUILT_APP" "$INSTALLED_APP"
pluginkit -a "$INSTALLED_EXTENSION"
pluginkit -e use -i "$EXTENSION_ID"
pluginkit -r "$BUILT_EXTENSION" >/dev/null 2>&1 || true
rm -rf -- "$BUILT_APP"
killall Finder >/dev/null 2>&1 || true

open_app() {
  /usr/bin/open -n "$INSTALLED_APP"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\" OR process == \"FinderToolsExtension\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --debug --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    pgrep -x FinderToolsExtension >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
