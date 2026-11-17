#!/bin/bash
# Build the conformance app for mac and dump what the spine plugin renders.
#
# Usage: ./run.sh <legacy|default> <output-dir> [extra ceramic build args...]
#
# Nothing is ever shown on screen: the app uses a hidden SDL window
# (clay_sdl_headless), is flagged as an agent app (LSUIElement, no Dock icon)
# and runs under tools/window-guard.swift, which kills it if a window,
# a Dock icon or a focus change ever shows up.
set -eu

cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"

MODE="${1:-}"
OUT="${2:-}"
if [ "$MODE" != "legacy" ] && [ "$MODE" != "default" ]; then
    echo "Usage: ./run.sh <legacy|default> <output-dir> [extra ceramic build args...]" >&2
    exit 1
fi
if [ -z "$OUT" ]; then
    echo "Missing output directory" >&2
    exit 1
fi
shift 2

CERAMIC="${CERAMIC:-$PROJECT_DIR/../../ceramic/tools/ceramic}"
APP="$PROJECT_DIR/project/mac/spine-conformance.app"
BIN="$APP/Contents/MacOS/spine-conformance"
GUARD="$PROJECT_DIR/results/bin/window-guard"

DEFINES=()
if [ "$MODE" = "legacy" ]; then
    DEFINES=(-D spine_legacy)
    [ -d data-40 ] || { echo "data-40 is missing (see tools/prepare-data.py)" >&2; exit 1; }
else
    [ -d data-43 ] || { echo "data-43 is missing (see tools/prepare-data.py)" >&2; exit 1; }
fi

mkdir -p "$PROJECT_DIR/results/bin"
if [ ! -x "$GUARD" ] || [ "tools/window-guard.swift" -nt "$GUARD" ]; then
    swiftc -O -o "$GUARD" tools/window-guard.swift
fi

"$CERAMIC" clay build mac --setup --assets "${DEFINES[@]+"${DEFINES[@]}"}" "$@"

# Agent app: no Dock icon, never activated
/usr/libexec/PlistBuddy -c "Delete :LSUIElement" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist"
# A freshly rebuilt app is killed by the system unless it is signed again
codesign --force --sign - --deep "$APP" >/dev/null 2>&1

mkdir -p "$OUT"
OUT_ABS="$(cd "$OUT" && pwd)"
SPINE_CONFORMANCE_OUT="$OUT_ABS" "$GUARD" "$BIN"
