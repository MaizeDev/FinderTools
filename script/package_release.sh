#!/usr/bin/env bash
#
# 构建 FinderTools（Release）并生成带安装界面的 DMG。
#
# 用法：
#   ./script/package_release.sh [版本号] [--regenerate-background]
#
#   版本号默认 1.1.2。
#   --regenerate-background 用 script/dmg/generate_background.swift 重绘背景，
#   再用 tiffutil 合成多分辨率 TIFF；平时复用已提交的 script/dmg/background.tiff。
#
# 依赖：
#   - Xcode 命令行工具（xcodebuild / codesign / tiffutil / hdiutil）
#   - dmgbuild，见 script/dmg/setup.sh（只需联网安装一次到 .build/dmg-venv）
#
# 本脚本不联网、不需要开发者证书，也不修改系统设置。
set -euo pipefail

VERSION="${1:-1.1.2}"
REGENERATE_BACKGROUND=0
if [[ "${2:-}" == "--regenerate-background" ]]; then
  REGENERATE_BACKGROUND=1
elif [[ -n "${2:-}" ]]; then
  echo "错误：未知参数“$2”" >&2
  echo "用法：$0 [版本号] [--regenerate-background]" >&2
  exit 2
fi

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

DMG_ASSETS_DIR="$ROOT_DIR/script/dmg"
BG_GENERATOR="$DMG_ASSETS_DIR/generate_background.swift"
BG_1X="$DMG_ASSETS_DIR/background.png"
BG_2X="$DMG_ASSETS_DIR/background@2x.png"
BG_TIFF="$DMG_ASSETS_DIR/background.tiff"
INSTALL_GUIDE="$DMG_ASSETS_DIR/install-guide.txt"
DMG_SETTINGS="$DMG_ASSETS_DIR/settings.py"

DMGBUILD="${DMGBUILD:-$ROOT_DIR/.build/dmg-venv/bin/dmgbuild}"
STAGING_DIR="$(mktemp -d /tmp/findertools-dmg.XXXXXX)"

cleanup() {
  case "$STAGING_DIR" in
    /tmp/findertools-dmg.*|/private/tmp/findertools-dmg.*)
      rm -rf -- "$STAGING_DIR"
      ;;
  esac
}
trap cleanup EXIT

die() {
  echo "错误：$*" >&2
  exit 1
}

# 路径安全检查：DMG 输出必须落在仓库的 dist/ 里
[[ "$DMG_PATH" == "$DIST_DIR"/* ]] || die "DMG 输出路径异常：$DMG_PATH"

# 依赖与素材检查
[[ -x "$DMGBUILD" ]] || die "未找到 dmgbuild（${DMGBUILD}）。请先运行 ./script/dmg/setup.sh 安装（需要联网一次）。"
for required in "$DMG_SETTINGS" "$INSTALL_GUIDE" "$BG_GENERATOR"; do
  [[ -f "$required" ]] || die "缺少文件：$required"
done

echo "==> 1/5 构建 Release（${APP_NAME} ${VERSION}）"
xcodebuild \
  -project "$ROOT_DIR/FinderTools.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  ENABLE_HARDENED_RUNTIME=YES \
  clean build

test -d "$BUILT_APP" || die "构建产物不存在：$BUILT_APP"
codesign --verify --deep --strict --verbose=2 "$BUILT_APP"

echo "==> 2/5 准备 DMG 背景"
if [[ "$REGENERATE_BACKGROUND" -eq 1 || ! -f "$BG_TIFF" ]]; then
  command -v swift >/dev/null 2>&1 || die "需要 swift 生成背景，但找不到 swift（请安装 Xcode 命令行工具）"
  echo "重绘背景：$BG_GENERATOR"
  swift "$BG_GENERATOR" "$DMG_ASSETS_DIR"
  tiffutil -cathidpicheck "$BG_1X" "$BG_2X" -out "$BG_TIFF"
else
  echo "复用已提交的背景：$BG_TIFF"
  echo "（如设计有改动，请运行：$0 $VERSION --regenerate-background）"
fi
[[ -f "$BG_TIFF" ]] || die "背景 TIFF 不存在：$BG_TIFF"

echo "==> 3/5 组装 DMG 内容"
mkdir -p "$DIST_DIR"
rm -f -- "$DMG_PATH"
ditto "$BUILT_APP" "$STAGING_DIR/$APP_NAME.app"
cp "$INSTALL_GUIDE" "$STAGING_DIR/安装说明 Install Guide.txt"
# Applications 的替身由 dmgbuild 的 symlinks 设置创建，无需在此处理

echo "==> 4/5 生成 DMG（dmgbuild）"
"$DMGBUILD" \
  -s "$DMG_SETTINGS" \
  -D app="$STAGING_DIR/$APP_NAME.app" \
  -D background="$BG_TIFF" \
  -D guide="$STAGING_DIR/安装说明 Install Guide.txt" \
  -D version="$VERSION" \
  "$APP_NAME $VERSION" "$DMG_PATH"

test -f "$DMG_PATH" || die "DMG 未生成：$DMG_PATH"

echo "==> 5/5 校验与输出"
hdiutil verify "$DMG_PATH"
SIZE_BYTES="$(stat -f%z "$DMG_PATH")"
SIZE_HUMAN="$(du -h "$DMG_PATH" | awk '{print $1}')"
SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
echo "DMG：$DMG_PATH"
echo "大小：$SIZE_BYTES 字节（${SIZE_HUMAN}）"
echo "SHA-256：$SHA256"
