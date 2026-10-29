#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/ChainedMac.app"
DMG="$ROOT/dist/ChainedMac-macOS-universal.dmg"
WEBSITE_DMG="$ROOT/website/downloads/ChainedMac-macOS-universal.dmg"
RESOURCES="$ROOT/Sources/ChainedMac/Resources"
ARM64_SCRATCH="$ROOT/.build/arm64"
X64_SCRATCH="$ROOT/.build/x86_64"

swift build -c release --package-path "$ROOT" --triple arm64-apple-macosx13 --scratch-path "$ARM64_SCRATCH"
swift build -c release --package-path "$ROOT" --triple x86_64-apple-macosx13 --scratch-path "$X64_SCRATCH"

ARM64_BINARY="$ARM64_SCRATCH/out/Products/Release/ChainedMac"
X64_BINARY="$X64_SCRATCH/out/Products/Release/ChainedMac"
mkdir -p "$ROOT/dist" "$ROOT/website/downloads"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$ARM64_BINARY" "$X64_BINARY" -output "$APP/Contents/MacOS/ChainedMac"
lipo -verify_arch arm64 "$APP/Contents/MacOS/ChainedMac"
lipo -verify_arch x86_64 "$APP/Contents/MacOS/ChainedMac"
cp "$RESOURCES/ChainedMacMenuBarMark.png" "$APP/Contents/Resources/ChainedMacMenuBarMark.png"
cp "$RESOURCES/ChainedMacAppIcon.icns" "$APP/Contents/Resources/ChainedMacAppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>ChainedMac</string>
  <key>CFBundleIdentifier</key><string>com.chainyourmac.app</string>
  <key>CFBundleName</key><string>ChainedMac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.8</string>
  <key>CFBundleVersion</key><string>9</string>
  <key>CFBundleIconFile</key><string>ChainedMacAppIcon.icns</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSAccessibilityUsageDescription</key><string>ChainedMac uses Accessibility to find, move, and resize app windows on your Mac.</string>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"
SIGNING_IDENTITY="${CHAINEDMAC_CODESIGN_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  if security find-identity -p codesigning 2>/dev/null | grep -Fq '"ChainedMac Local Code Signing"'; then
    SIGNING_IDENTITY="ChainedMac Local Code Signing"
  else
    SIGNING_IDENTITY="-"
  fi
fi
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP"
STAGING_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/ChainedMac-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIRECTORY"' EXIT
ditto "$APP" "$STAGING_DIRECTORY/ChainedMac.app"
ln -s /Applications "$STAGING_DIRECTORY/Applications"
rm -f "$DMG" "$WEBSITE_DMG"
hdiutil create -volname ChainedMac -srcfolder "$STAGING_DIRECTORY" -ov -format UDZO "$DMG"
cp "$DMG" "$WEBSITE_DMG"
printf 'Created %s\n' "$APP"
printf 'Created %s\n' "$DMG"
