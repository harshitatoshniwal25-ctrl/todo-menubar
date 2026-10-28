#!/bin/bash
# Assembles "to do.app" — a real menu bar app bundle you can drag to /Applications.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="to do"
BUNDLE_ID="${BUNDLE_ID:-com.harshita.todo}"
VERSION="0.1.0"
DEST="dist/${APP_NAME}.app"

echo "building release…"
swift build -c release

rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"

cp .build/release/ToDo "$DEST/Contents/MacOS/ToDo"

# The SwiftPM resource bundle carries the embedded fonts.
if [ -d .build/release/ToDo_ToDo.bundle ]; then
  cp -R .build/release/ToDo_ToDo.bundle "$DEST/Contents/Resources/"
fi

cat > "$DEST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>ToDo</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <!-- No Dock icon, no app switcher entry: it lives in the menu bar. -->
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature, so it launches on this Mac without a Developer ID.
# For anyone else's Mac you need the $99/yr cert and `xcrun notarytool`.
codesign --force --sign - --timestamp=none "$DEST" >/dev/null 2>&1 || {
  echo "note: ad-hoc signing failed; the app will still run locally"
}

echo "built $DEST"
echo "drag it to /Applications, or: open \"$DEST\""
