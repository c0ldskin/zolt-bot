#!/bin/bash
# Builds Zolt.app and installs it to ~/Applications.
# Usage: ./build.sh [--run] [--shortcut] [--release] [--no-install]
#   --run         open Zolt after installing
#   --shortcut    add a Zolt shortcut to the Desktop (kept up to date once it exists)
#   --release     build for Apple Silicon and Intel, zip it to build/Zolt-<version>.zip, don't install
#   --no-install  just build (used by CI)
set -euo pipefail
cd "$(dirname "$0")"

RUN=0 SHORTCUT=0 RELEASE=0 INSTALL_IT=1
for arg in "$@"; do
    case "$arg" in
        --run) RUN=1 ;;
        --shortcut) SHORTCUT=1 ;;
        --release) RELEASE=1; INSTALL_IT=0 ;;
        --no-install) INSTALL_IT=0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

APP=build/Zolt.app
INSTALL="$HOME/Applications/Zolt.app"
FRAMEWORKS=(-framework Cocoa -framework AVFoundation -framework Speech -framework Carbon -framework CoreAudio -framework ScreenCaptureKit)
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if [[ $RELEASE == 1 ]]; then
    # One binary that runs on both Apple Silicon and Intel Macs.
    for arch in arm64 x86_64; do
        swiftc -swift-version 5 -O -target "$arch-apple-macos26.0" Sources/*.swift -o "build/Zolt-$arch" "${FRAMEWORKS[@]}"
    done
    lipo -create build/Zolt-arm64 build/Zolt-x86_64 -output "$APP/Contents/MacOS/Zolt"
    rm build/Zolt-arm64 build/Zolt-x86_64
else
    swiftc -swift-version 5 -O Sources/*.swift -o "$APP/Contents/MacOS/Zolt" "${FRAMEWORKS[@]}"
fi
cp Info.plist "$APP/Contents/Info.plist"

# App icon, drawn from Zolt's own sprite.
"$APP/Contents/MacOS/Zolt" --render-icon build/Zolt.iconset
iconutil -c icns build/Zolt.iconset -o "$APP/Contents/Resources/Zolt.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ $RELEASE == 1 ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
    ZIP="build/Zolt-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "Packaged $ZIP"
fi
[[ $INSTALL_IT == 1 ]] || exit 0

# Install, restarting Zolt if it was running.
WAS_RUNNING=0
if pgrep -x Zolt >/dev/null; then WAS_RUNNING=1; pkill -x Zolt; sleep 1; fi
mkdir -p "$HOME/Applications"
rm -rf "$INSTALL"
ditto "$APP" "$INSTALL"
touch "$INSTALL"
echo "Installed $INSTALL"

if [[ $SHORTCUT == 1 || -L "$HOME/Desktop/Zolt" ]]; then
    ln -sfn "$INSTALL" "$HOME/Desktop/Zolt"
    echo "Desktop shortcut: ~/Desktop/Zolt"
fi

if [[ $RUN == 1 || $WAS_RUNNING == 1 ]]; then
    open "$INSTALL"
fi
