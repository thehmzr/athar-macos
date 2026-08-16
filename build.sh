#!/bin/bash
# Builds Athar.app with the Swift toolchain from Command Line Tools — no Xcode required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/build/Athar.app"
CONTENTS="$APP/Contents"
DEPLOY_TARGET="14.0"

ARCH="$(uname -m)"
case "$ARCH" in
  arm64) TARGET="arm64-apple-macosx$DEPLOY_TARGET" ;;
  x86_64) TARGET="x86_64-apple-macosx$DEPLOY_TARGET" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

echo "==> Cleaning"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

echo "==> Compiling ($TARGET)"
SOURCES=$(find "$ROOT/Sources" -name '*.swift' | sort)
# shellcheck disable=SC2086
swiftc \
  -target "$TARGET" \
  -parse-as-library \
  -O \
  -swift-version 5 \
  -framework AppKit -framework SwiftUI -framework ServiceManagement \
  $SOURCES \
  -o "$CONTENTS/MacOS/Athar"

echo "==> Copying resources"
cp -R "$ROOT/Resources/Fonts" "$CONTENTS/Resources/Fonts"
cp -R "$ROOT/Resources/Data"  "$CONTENTS/Resources/Data"
# Bundle.url(forResource:) without a subdirectory is the fallback lookup path.
cp "$ROOT/Resources/Data/"*.json "$CONTENTS/Resources/"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi

echo "==> Writing Info.plist"
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Athar</string>
    <key>CFBundleIdentifier</key><string>com.athar.quotewidget</string>
    <key>CFBundleName</key><string>Athar</string>
    <key>CFBundleDisplayName</key><string>Athar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>$DEPLOY_TARGET</string>
    <key>NSHighResolutionCapable</key><true/>
    <!-- Menu-bar only: no Dock icon, no app switcher entry. -->
    <key>LSUIElement</key><true/>
    <!-- Auto-registers every face in Resources/Fonts at launch. -->
    <key>ATSApplicationFontsPath</key><string>Fonts</string>
    <key>NSHumanReadableCopyright</key><string>Fonts are licensed under the SIL Open Font License.</string>
</dict>
</plist>
PLIST

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP" 2>/dev/null

echo "==> Built $APP"
du -sh "$APP" | awk '{print "    size: " $1}'

# ./build.sh --dmg  packages a drag-to-Applications disk image.
if [ "${1:-}" = "--dmg" ]; then
  DMG="$ROOT/build/Athar.dmg"
  STAGE="$ROOT/build/dmg"
  echo "==> Packaging disk image"
  rm -rf "$STAGE" "$DMG"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/Athar.app"
  # The Applications symlink is what makes it a drag-and-drop installer.
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -quiet -volname "Athar" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG"
  rm -rf "$STAGE"
  echo "    $DMG"
  du -sh "$DMG" | awk '{print "    size: " $1}'
fi

# ./build.sh --install  replaces the copy in /Applications and relaunches it.
if [ "${1:-}" = "--install" ]; then
  DEST="/Applications/Athar.app"
  echo "==> Installing to $DEST"
  # Quit the running copy first, or the replaced bundle keeps the old code.
  pkill -f "Athar.app/Contents/MacOS/Athar" 2>/dev/null || true
  sleep 1
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  open "$DEST"
  echo "    installed and launched"
fi
