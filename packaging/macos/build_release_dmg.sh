#!/bin/zsh
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
PACKAGING="$ROOT/packaging/macos"
OUTPUTS="$ROOT/outputs"
BUILD="$ROOT/.build/macos"

source "$PACKAGING/app-metadata.env"

APP_BUNDLE="$OUTPUTS/$APP_NAME.app"
DMG_STAGING="$BUILD/dmg-staging"
DMG_PATH="$OUTPUTS/$APP_NAME-$APP_VERSION.dmg"
SIGN_IDENTITY="${PAPER_FORGE_SIGN_IDENTITY:-}"
ENTITLEMENTS="$PACKAGING/PaperForge.entitlements"

"$PACKAGING/build_native_app.sh"

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

if [[ -n "$SIGN_IDENTITY" ]]; then
  if ! security find-identity -v -p codesigning | grep -F "$SIGN_IDENTITY" >/dev/null; then
    echo "Signing identity not found: $SIGN_IDENTITY"
    echo "Install the certificate in Keychain or set PAPER_FORGE_SIGN_IDENTITY to an available identity."
    exit 1
  fi

  codesign \
    --force \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$DMG_STAGING/$APP_NAME.app"
else
  echo "PAPER_FORGE_SIGN_IDENTITY is not set. Creating ad-hoc signed local DMG."
fi

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi

echo "Created $DMG_PATH"
