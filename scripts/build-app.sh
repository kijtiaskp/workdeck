#!/bin/bash
set -euo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
readonly APP_NAME="Workdeck"
readonly APP_BUNDLE="$PROJECT_DIR/dist/$APP_NAME.app"
readonly INSTALL_PATH="/Applications/$APP_NAME.app"
readonly COMMAND_LINE_TOOLS_FALLBACK_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"

cd "$PROJECT_DIR"
if [[ -z "${SDKROOT:-}" && ! -d /Applications/Xcode.app && -d "$COMMAND_LINE_TOOLS_FALLBACK_SDK" ]]; then
  export SDKROOT="$COMMAND_LINE_TOOLS_FALLBACK_SDK"
fi
/usr/bin/swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp Resources/Info.plist "$APP_BUNDLE/Contents/"
cp Resources/AppIcon.icns Resources/MenuBarIcon.png Resources/MenuBarIcon@2x.png "$APP_BUNDLE/Contents/Resources/"
codesign --force --deep --sign - "$APP_BUNDLE"

pkill -x "$APP_NAME" || true
while pgrep -x "$APP_NAME" >/dev/null; do sleep 0.2; done
rm -rf "$INSTALL_PATH"
cp -R "$APP_BUNDLE" "$INSTALL_PATH"
open "$INSTALL_PATH" || { sleep 1; open "$INSTALL_PATH"; }

echo "Installed $INSTALL_PATH"
