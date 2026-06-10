#!/bin/zsh
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
ICONSET="$ROOT/resources/AppIcon.iconset"
ICNS="$ROOT/resources/AppIcon.icns"
MODULE_CACHE="$ROOT/.build/macos/module-cache"

cd "$ROOT"
mkdir -p "$MODULE_CACHE"
swift -module-cache-path "$MODULE_CACHE" "$ROOT/packaging/macos/generate_app_icon.swift"
rm -f "$ICNS"
iconutil -c icns "$ICONSET" -o "$ICNS"

echo "Created $ICNS"
