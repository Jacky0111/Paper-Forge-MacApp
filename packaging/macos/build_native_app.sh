#!/bin/zsh
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
PACKAGING="$ROOT/packaging/macos"
SRC="$ROOT/src/pdfsuite"
OUTPUTS="$ROOT/outputs"
BUILD="$ROOT/.build/macos"

source "$PACKAGING/app-metadata.env"

APP_BUNDLE="$OUTPUTS/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
MODULE_CACHE="$BUILD/module-cache"
ICON_SOURCE="$ROOT/resources/AppIcon.icns"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES" "$MODULE_CACHE"

swift_sources=(
  "$SRC/core/DomainModels.swift"
  "$SRC/core/CancellationToken.swift"
  "$SRC/core/ModuleContracts.swift"
  "$SRC/services/FileImporting.swift"
  "$SRC/services/JobStoring.swift"
  "$SRC/services/ModuleRunning.swift"
  "$SRC/services/ProgressPublishing.swift"
  "$SRC/services/SettingsStoring.swift"
  "$SRC/modules/ModuleManifest.swift"
  "$SRC/modules/ModuleRegistry.swift"
  "$SRC/modules/pdf_to_images/PDFToImagesModule.swift"
  "$SRC/modules/txt_to_pdf/TxtToPDFModule.swift"
  "$SRC/modules/flatten_pdf/FlattenPDFModule.swift"
  "$SRC/app/AppContainer.swift"
  "$SRC/app/AppState.swift"
  "$SRC/app/ContentView.swift"
  "$SRC/app/PaperForgeApp.swift"
)

swiftc \
  -module-cache-path "$MODULE_CACHE" \
  -o "$MACOS/$APP_NAME" \
  "${swift_sources[@]}"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$APP_BUNDLE_IDENTIFIER</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>NSHumanReadableCopyright</key>
  <string>$APP_COPYRIGHT</string>
  <key>LSMinimumSystemVersion</key>
  <string>$APP_MINIMUM_MACOS</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$RESOURCES/AppIcon.icns"
fi

cat > "$RESOURCES/README.txt" <<README
Paper Forge is the native SwiftUI Phase 1 MVP build.

Launch by double-clicking the app bundle.
README

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Created $APP_BUNDLE"
