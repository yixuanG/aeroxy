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
  build

cp -R "$APP_PATH" "$PACKAGE_DIR/"

# Sign with codesign (bypasses xcodebuild account issues)
SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application}"

# Check if app has a real signature (not just ad-hoc)
SIGN_INFO=$(codesign -dv "$PACKAGE_DIR/Aeroxy.app" 2>&1) || true
IS_ADHOC=$(echo "$SIGN_INFO" | grep -c "Signature=adhoc" || true)

if [[ "$IS_ADHOC" -eq 0 ]] && codesign --verify --verbose "$PACKAGE_DIR/Aeroxy.app" 2>/dev/null; then
  echo "App already signed with a valid certificate."
else
  # Try preferred identity first, fall back to any available identity
  ACTUAL_IDENTITY=""
  if security find-identity -v -p basic 2>/dev/null | grep -q "$SIGNING_IDENTITY"; then
    ACTUAL_IDENTITY="$SIGNING_IDENTITY"
  elif security find-identity -v -p basic 2>/dev/null | grep -q "Apple Development"; then
    ACTUAL_IDENTITY="Apple Development"
  fi

  if [[ -n "$ACTUAL_IDENTITY" ]]; then
    echo "Signing with $ACTUAL_IDENTITY..."

    # Sign embedded CLI helper first
    CLI_PATH="$PACKAGE_DIR/Aeroxy.app/Contents/Library/Helpers/aeroxy"
    if [[ -f "$CLI_PATH" ]]; then
      codesign --force --options runtime --timestamp --sign "$ACTUAL_IDENTITY" "$CLI_PATH"
    fi

    # Then sign the app bundle with all entitlements
    codesign --force --options runtime --timestamp --sign "$ACTUAL_IDENTITY" \
      --entitlements "$ROOT_DIR/Aeroxy/Resources/Aeroxy.entitlements" \
      --deep "$PACKAGE_DIR/Aeroxy.app"
    echo "Signed with $ACTUAL_IDENTITY."
  else
    echo "WARNING: No signing certificate found. DMG will be unsigned."
    echo "Create a Developer ID Application certificate for distribution."
  fi
fi

ln -s /Applications "$PACKAGE_DIR/Applications"
hdiutil create \
  -volname "Aeroxy" \
  -srcfolder "$PACKAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"

# Notarization (requires paid Apple Developer account)
if [[ "${NOTARIZE:-0}" == "1" ]]; then
  NOTARY_ARGS=()

  if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
  elif [[ -n "${APPSTORE_CONNECT_API_KEY:-}" ]]; then
    NOTARY_ARGS=(
      --key "$APPSTORE_CONNECT_API_KEY"
      --key-id "${APPSTORE_CONNECT_API_KEY_ID:?}"
      --issuer "${APPSTORE_CONNECT_API_ISSUER:?}"
    )
  elif [[ -n "${APPLE_ID:-}" ]]; then
    NOTARY_ARGS=(
      --apple-id "$APPLE_ID"
      --team-id "${APPLE_TEAM_ID:?}"
      --password "${APPLE_APP_SPECIFIC_PASSWORD:?}"
    )
  else
    echo "NOTARIZE=1 but no credentials found."
    exit 1
  fi

  echo "Submitting DMG for notarization..."
  xcrun notarytool submit "$DMG_PATH" "${NOTARY_ARGS[@]}" --wait

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$DMG_PATH"
  echo "Notarization done."
fi
