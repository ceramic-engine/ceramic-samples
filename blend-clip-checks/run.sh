#!/bin/bash
# Build and run the pixel checks of Blending.MULTIPLY, Blending.SCREEN and
# Visual.clipInverted, without any window (hidden SDL window, agent app, window guard).
set -eu
cd "$(dirname "$0")"
DIR="$(pwd)"
CERAMIC="${CERAMIC:-$DIR/../../ceramic/tools/ceramic}"
GUARD_SRC="$DIR/../spine-conformance/tools/window-guard.swift"
GUARD="$DIR/out/window-guard"
mkdir -p "$DIR/out"
if [ ! -x "$GUARD" ] || [ "$GUARD_SRC" -nt "$GUARD" ]; then
    swiftc -O -o "$GUARD" "$GUARD_SRC"
fi
"$CERAMIC" clay build mac --setup --assets "$@"
APP="$DIR/project/mac/blend-clip-checks.app"
/usr/libexec/PlistBuddy -c "Delete :LSUIElement" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist"
codesign --force --sign - --deep "$APP" >/dev/null 2>&1
WINDOW_GUARD_TIMEOUT=120 "$GUARD" "$APP/Contents/MacOS/blend-clip-checks"
