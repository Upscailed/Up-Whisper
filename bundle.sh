#!/bin/bash
# Bouwt Up/Whisper als distribueerbare .app-bundle.
# Gebruik: ./bundle.sh
set -euo pipefail

# Weergavenaam van de .app-bundle (zichtbaar in Finder)
APP_NAME="Up Whisper"
# Naam van de Swift-binary (technisch, moet matchen met CFBundleExecutable)
BIN_NAME="UpWhisper"
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

# Executable (binary-naam blijft UpWhisper, matcht CFBundleExecutable)
cp "$BIN_DIR/$BIN_NAME" "$APP/Contents/MacOS/$BIN_NAME"

# Info.plist + icoon
cp "$RES/Info.plist" "$APP/Contents/Info.plist"
cp "$RES/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# SPM-resourcebundles (o.a. UpWhisper_UpWhisper.bundle voor Bundle.module)
# In Contents/Resources/ — daar vindt Bundle.main.resourceURL ze als .app-bundle.
for b in "$BIN_DIR"/*.bundle; do
  [ -e "$b" ] || continue
  cp -R "$b" "$APP/Contents/Resources/"
done

# Ad-hoc signeren — houdt Accessibility-permissie stabiel tussen builds
echo "→ Ad-hoc signeren..."
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign overgeslagen)"

echo "✓ Klaar: $APP"
