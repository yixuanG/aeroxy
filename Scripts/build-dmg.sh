#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
PACKAGE_DIR="$BUILD_DIR/dmg-root"
APP_PATH="$DERIVED_DATA/Build/Products/Release/Aeroxy.app"
DMG_PATH="$BUILD_DIR/Aeroxy.dmg"

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

xcodebuild \
  -project "$ROOT_DIR/Aeroxy.xcodeproj" \
  -scheme Aeroxy \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

cp -R "$APP_PATH" "$PACKAGE_DIR/"
ln -s /Applications "$PACKAGE_DIR/Applications"
hdiutil create \
  -volname "Aeroxy" \
  -srcfolder "$PACKAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"
