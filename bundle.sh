#!/bin/bash
# Bouwt UpWhisper als distribueerbare .app-bundle.
# Gebruik: ./bundle.sh
set -euo pipefail

APP_NAME="UpWhisper"
BUILD_CONFIG="release"
ROOT="$(cd "$(dirname "$0")" && pwd)"
RES="$ROOT/Sources/UpWhisper/Resources"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "→ Release build..."
swift build -c "$BUILD_CONFIG"

BIN_DIR="$ROOT/.build/$BUILD_CONFIG"

echo "→ .app-structuur opbouwen..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Executable
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# Info.plist + icoon
cp "$RES/Info.plist" "$APP/Contents/Info.plist"
cp "$RES/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# SPM-resourcebundles (o.a. UpWhisper_UpWhisper.bundle voor Bundle.module)
# In Contents/Resources/ — daar vindt Bundle.module ze via Bundle.main.resourceURL.
for b in "$BIN_DIR"/*.bundle; do
  [ -e "$b" ] || continue
  cp -R "$b" "$APP/Contents/Resources/"
done

# Ad-hoc signeren — houdt Accessibility-permissie stabiel tussen builds
echo "→ Ad-hoc signeren..."
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign overgeslagen)"

echo "✓ Klaar: $APP"
