#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/windows/ChainedMac.Windows/ChainedMac.Windows.csproj"
PUBLISH_DIRECTORY="$ROOT/dist/windows-x64"
ZIP="$ROOT/dist/ChainedMac-Windows-x64.zip"
WEBSITE_ZIP="$ROOT/website/downloads/ChainedMac-Windows-x64.zip"
DOTNET_CLI="${DOTNET_CLI:-dotnet}"

rm -rf "$PUBLISH_DIRECTORY"
"$DOTNET_CLI" publish "$PROJECT" \
  --configuration Release \
  --runtime win-x64 \
  --self-contained true \
  --output "$PUBLISH_DIRECTORY" \
  -p:PublishSingleFile=true \
  -p:EnableCompressionInSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:DebugType=None

rm -f "$ZIP" "$WEBSITE_ZIP"
cat > "$PUBLISH_DIRECTORY/README.txt" <<'README'
ChainedMac for Windows x64

1. Extract this ZIP folder.
2. Run ChainedMac.exe.
3. Keep the app open from the notification area near the clock.
4. Arrange open windows, then use Shift+Left and Shift+Right to focus them.

Ctrl+Alt+R restores the positions saved when the strip was arranged.
Right-click the notification-area icon to open ChainedMac or quit.
README

(
  cd "$PUBLISH_DIRECTORY"
  zip -qr "$ZIP" .
)
cp "$ZIP" "$WEBSITE_ZIP"
printf 'Created %s\n' "$ZIP"
