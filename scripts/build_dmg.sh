#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="Clipline"
BUILD_DIR="build"
DMG_NAME="${APP_NAME}.dmg"
DMG_TMP="${BUILD_DIR}/dmg-tmp"
APP_PATH=""

rm -rf "$BUILD_DIR"
mkdir -p "$DMG_TMP"

echo "==> Build App"
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  build

APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" | head -n 1)

if [ ! -d "$APP_PATH" ]; then
  echo "❌ App not found"
  exit 1
fi

cp -R "$APP_PATH" "$DMG_TMP"

ln -s /Applications "$DMG_TMP/Applications"

echo "==> Create DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_TMP" \
  -ov \
  -format UDZO \
  "$BUILD_DIR/$DMG_NAME"

echo "✅ DMG created: $BUILD_DIR/$DMG_NAME"