#!/bin/bash
# Builds Bolt.app, installs it to ~/Applications with a shortcut on the Desktop.
# Usage: ./build.sh [--run]
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Bolt.app
INSTALL="$HOME/Applications/Bolt.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -swift-version 5 -O Sources/*.swift -o "$APP/Contents/MacOS/Bolt" \
    -framework Cocoa -framework AVFoundation -framework Speech -framework Carbon -framework CoreAudio -framework ScreenCaptureKit
cp Info.plist "$APP/Contents/Info.plist"

# App icon, drawn from Bolt's own sprite.
"$APP/Contents/MacOS/Bolt" --render-icon build/Bolt.iconset
iconutil -c icns build/Bolt.iconset -o "$APP/Contents/Resources/Bolt.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

# Install (restarting Bolt if it was running) and keep the Desktop shortcut pointing at it.
WAS_RUNNING=0
if pgrep -x Bolt >/dev/null; then WAS_RUNNING=1; pkill -x Bolt; sleep 1; fi
mkdir -p "$HOME/Applications"
rm -rf "$INSTALL"
ditto "$APP" "$INSTALL"
ln -sfn "$INSTALL" "$HOME/Desktop/Bolt"
touch "$INSTALL"
echo "Installed $INSTALL (Desktop shortcut: ~/Desktop/Bolt)"

if [[ "${1:-}" == "--run" || $WAS_RUNNING == 1 ]]; then
    open "$INSTALL"
fi
