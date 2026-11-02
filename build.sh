#!/bin/bash
# Builds Zolt.app (or its Arabic sibling, Zamil.app) and installs it to ~/Applications.
# Usage: ./build.sh [--character zolt|zamil] [--run] [--shortcut] [--release] [--no-install]
#   --character   which character to build (default: zolt)
#   --run         open the app after installing
#   --shortcut    add a shortcut to the Desktop (kept up to date once it exists)
#   --release     build for Apple Silicon and Intel, zip it to build/<Name>-<version>.zip, don't install
#   --no-install  just build (used by CI)
set -euo pipefail
cd "$(dirname "$0")"

CHARACTER=zolt RUN=0 SHORTCUT=0 RELEASE=0 INSTALL_IT=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --character) CHARACTER="${2:-}"; shift ;;
        --run) RUN=1 ;;
        --shortcut) SHORTCUT=1 ;;
        --release) RELEASE=1; INSTALL_IT=0 ;;
        --no-install) INSTALL_IT=0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done
case "$CHARACTER" in
    zolt) NAME=Zolt HOTKEY=Space ;;
    zamil) NAME=Zamil HOTKEY=Z ;;
    *) echo "Unknown character: $CHARACTER (use zolt or zamil)" >&2; exit 1 ;;
esac

APP="build/$NAME.app"
INSTALL="$HOME/Applications/$NAME.app"
FRAMEWORKS=(-framework Cocoa -framework AVFoundation -framework Speech -framework Carbon -framework CoreAudio -framework ScreenCaptureKit)
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if [[ $RELEASE == 1 ]]; then
    # One binary that runs on both Apple Silicon and Intel Macs.
    for arch in arm64 x86_64; do
        swiftc -swift-version 5 -O -target "$arch-apple-macos26.0" Sources/*.swift -o "build/$NAME-$arch" "${FRAMEWORKS[@]}"
    done
    lipo -create "build/$NAME-arm64" "build/$NAME-x86_64" -output "$APP/Contents/MacOS/$NAME"
    rm "build/$NAME-arm64" "build/$NAME-x86_64"
else
    swiftc -swift-version 5 -O Sources/*.swift -o "$APP/Contents/MacOS/$NAME" "${FRAMEWORKS[@]}"
fi

# Same Info.plist for both, with the character's name, ID and hotkey swapped in.
sed -e "s/Zolt/$NAME/g" -e "s/io\.github\.c0ldskin\.zolt/io.github.c0ldskin.$CHARACTER/" \
    -e "s/Control-Option-Space/Control-Option-$HOTKEY/" Info.plist > "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :RobotCharacter string $CHARACTER" "$APP/Contents/Info.plist"
if [[ $CHARACTER == zamil ]]; then
    # Run in Arabic, so macOS lays out Zamil's menus and dialogs right to left.
    /usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string ar" -c "Add :CFBundleLocalizations array" \
        -c "Add :CFBundleLocalizations:0 string ar" "$APP/Contents/Info.plist"
    mkdir -p "$APP/Contents/Resources/ar.lproj"
fi

# App icon, drawn from the character's own sprite.
"$APP/Contents/MacOS/$NAME" --render-icon "build/$NAME.iconset"
iconutil -c icns "build/$NAME.iconset" -o "$APP/Contents/Resources/$NAME.icns"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ $RELEASE == 1 ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
    ZIP="build/$NAME-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "Packaged $ZIP"
fi
[[ $INSTALL_IT == 1 ]] || exit 0

# Install, restarting the app if it was running.
WAS_RUNNING=0
if pgrep -x "$NAME" >/dev/null; then WAS_RUNNING=1; pkill -x "$NAME"; sleep 1; fi
mkdir -p "$HOME/Applications"
rm -rf "$INSTALL"
ditto "$APP" "$INSTALL"
touch "$INSTALL"
echo "Installed $INSTALL"

if [[ $SHORTCUT == 1 || -L "$HOME/Desktop/$NAME" ]]; then
    ln -sfn "$INSTALL" "$HOME/Desktop/$NAME"
    echo "Desktop shortcut: ~/Desktop/$NAME"
fi

if [[ $RUN == 1 || $WAS_RUNNING == 1 ]]; then
    open "$INSTALL"
fi
