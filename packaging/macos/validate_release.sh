#!/bin/zsh
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
PACKAGING="$ROOT/packaging/macos"

source "$PACKAGING/app-metadata.env"

APP_BUNDLE="$ROOT/outputs/$APP_NAME.app"
DMG_PATH="$ROOT/outputs/$APP_NAME-$APP_VERSION.dmg"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle: $APP_BUNDLE"
  exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing DMG: $DMG_PATH"
  exit 1
fi

plutil -lint "$APP_BUNDLE/Contents/Info.plist"
test -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
file "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
hdiutil imageinfo "$DMG_PATH" >/dev/null

echo "Code signing status:"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" || true

echo "Gatekeeper status:"
spctl --assess --type execute --verbose "$APP_BUNDLE" || true

echo "Release artifact validation completed."
