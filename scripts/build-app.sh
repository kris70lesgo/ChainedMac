#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/ChainYourMac.app"
ZIP="$ROOT/dist/ChainYourMac-macOS-universal.zip"
WEBSITE_ZIP="$ROOT/website/downloads/ChainYourMac-macOS-universal.zip"
RESOURCES="$ROOT/Sources/ChainYourMac/Resources"
ARM64_SCRATCH="$ROOT/.build/arm64"
X64_SCRATCH="$ROOT/.build/x86_64"

swift build -c release --package-path "$ROOT" --triple arm64-apple-macosx13 --scratch-path "$ARM64_SCRATCH"
swift build -c release --package-path "$ROOT" --triple x86_64-apple-macosx13 --scratch-path "$X64_SCRATCH"

ARM64_BINARY="$ARM64_SCRATCH/out/Products/Release/ChainYourMac"
X64_BINARY="$X64_SCRATCH/out/Products/Release/ChainYourMac"
mkdir -p "$ROOT/dist" "$ROOT/website/downloads"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$ARM64_BINARY" "$X64_BINARY" -output "$APP/Contents/MacOS/ChainYourMac"
lipo -verify_arch arm64 "$APP/Contents/MacOS/ChainYourMac"
lipo -verify_arch x86_64 "$APP/Contents/MacOS/ChainYourMac"
cp "$RESOURCES/ChainYourMacMenuBarMark.png" "$APP/Contents/Resources/ChainYourMacMenuBarMark.png"
cp "$RESOURCES/ChainYourMacAppIcon.icns" "$APP/Contents/Resources/ChainYourMacAppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>ChainYourMac</string>
  <key>CFBundleIdentifier</key><string>com.chainyourmac.app</string>
  <key>CFBundleName</key><string>ChainYourMac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>ChainYourMacAppIcon.icns</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSAccessibilityUsageDescription</key><string>ChainYourMac uses Accessibility to find, move, and resize app windows on your Mac.</string>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
rm -f "$ZIP" "$WEBSITE_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
cp "$ZIP" "$WEBSITE_ZIP"
printf 'Created %s\n' "$APP"
printf 'Created %s\n' "$ZIP"
