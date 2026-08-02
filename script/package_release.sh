#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0}"
APP_NAME="FinderTools"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+([.][0-9]+)?$ ]]; then
  echo "版本号格式不正确，例如：1.0 或 1.0.1" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/ReleaseDerivedData"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
STAGING_DIR="$(mktemp -d /tmp/findertools-dmg.XXXXXX)"

cleanup() {
  case "$STAGING_DIR" in
    /tmp/findertools-dmg.*|/private/tmp/findertools-dmg.*)
      rm -rf -- "$STAGING_DIR"
      ;;
  esac
}
trap cleanup EXIT

xcodebuild \
  -project "$ROOT_DIR/FinderTools.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  ENABLE_HARDENED_RUNTIME=YES \
  clean build

test -d "$BUILT_APP"
codesign --verify --deep --strict --verbose=2 "$BUILT_APP"

mkdir -p "$DIST_DIR"
ditto "$BUILT_APP" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

shasum -a 256 "$DMG_PATH"
echo "DMG 已生成：$DMG_PATH"
