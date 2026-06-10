#!/bin/zsh
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
PACKAGING="$ROOT/packaging/macos"

source "$PACKAGING/app-metadata.env"

DMG_PATH="$ROOT/outputs/$APP_NAME-$APP_VERSION.dmg"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing DMG: $DMG_PATH"
  echo "Run packaging/macos/build_release_dmg.sh first."
  exit 1
fi

if [[ -z "$APPLE_ID" || -z "$APPLE_TEAM_ID" || -z "$APPLE_APP_PASSWORD" ]]; then
  echo "Missing notarization environment variables."
  echo "Set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_PASSWORD before running."
  exit 1
fi

if ! codesign --verify --verbose "$DMG_PATH" >/dev/null 2>&1; then
  echo "The DMG is not signed. Set PAPER_FORGE_SIGN_IDENTITY and rebuild the release DMG before notarizing."
  exit 1
fi

xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait

xcrun stapler staple "$DMG_PATH"
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH"

echo "Notarized and stapled $DMG_PATH"
