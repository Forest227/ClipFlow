#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
DMG_ROOT_DIR="$RELEASE_DIR/dmg-root"
APP_NAME="ClipFlow"
APP_PATH="$DIST_DIR/$APP_NAME.app"

RAW_VERSION="${1:-${CLIPFLOW_VERSION:-0.1.0}}"
TAG_NAME="${RAW_VERSION#refs/tags/}"
BUNDLE_VERSION="${TAG_NAME#v}"
BUILD_NUMBER="${CLIPFLOW_BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
DMG_NAME="$APP_NAME-$TAG_NAME.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
SHA_PATH="$DMG_PATH.sha256"

if [[ -z "$TAG_NAME" ]]; then
  echo "Missing release version or tag name." >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"

CLIPFLOW_VERSION="$BUNDLE_VERSION" CLIPFLOW_BUILD_NUMBER="$BUILD_NUMBER" "$ROOT_DIR/scripts/build_app.sh"

rm -rf "$DMG_ROOT_DIR"
mkdir -p "$DMG_ROOT_DIR"
cp -R "$APP_PATH" "$DMG_ROOT_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT_DIR/Applications"

rm -f "$DMG_PATH" "$SHA_PATH"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT_DIR" \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH" >/dev/null

(
  cd "$ROOT_DIR"
  shasum -a 256 "dist/release/$DMG_NAME" > "$SHA_PATH"
)

echo "Built release artifacts:"
echo "$DMG_PATH"
echo "$SHA_PATH"
