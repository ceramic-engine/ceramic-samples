#!/bin/bash
# Spine plugin benchmark.
#
#   ./bench.sh build <legacy|default> [label]
#       Release build (ceramic_no_hxcpp_checks), copied to results/apps/<label>.app
#       (label defaults to the mode).
#
#   ./bench.sh run <label,label,...> <scenario,scenario,...> [repetitions]
#       Runs every scenario for every build, alternating builds on each repetition,
#       and appends the BENCH lines to results/<label>/<scenario>.log
#       (or <scenario>-control.log when SPINE_BENCH_CONTROL=1: spines never updated,
#       the reference for allocation measurements)
#
# Nothing is ever shown on screen: hidden SDL window (clay_sdl_headless), agent
# app (LSUIElement, no Dock icon), and every run goes through the window guard of
# spine-conformance, which kills the process if a window, a Dock icon or a focus
# change shows up.
set -eu

cd "$(dirname "$0")"
BENCH_DIR="$(pwd)"
CERAMIC="${CERAMIC:-$BENCH_DIR/../../ceramic/tools/ceramic}"
GUARD_SRC="$BENCH_DIR/../spine-conformance/tools/window-guard.swift"
GUARD="$BENCH_DIR/results/bin/window-guard"

ensure_guard() {
    mkdir -p "$BENCH_DIR/results/bin"
    if [ ! -x "$GUARD" ] || [ "$GUARD_SRC" -nt "$GUARD" ]; then
        swiftc -O -o "$GUARD" "$GUARD_SRC"
    fi
}

cmd_build() {
    local mode="${1:-}"
    local label="${2:-$mode}"
    local defines=(-D ceramic_no_hxcpp_checks)
    if [ "$mode" = "legacy" ]; then
        defines+=(-D spine_legacy)
    elif [ "$mode" != "default" ]; then
        echo "Unknown mode: $mode" >&2
        exit 1
    fi
    case "$label" in
        ""|*/*|.*) echo "Invalid label: $label" >&2; exit 1 ;;
    esac
    "$CERAMIC" clay build mac --setup --assets "${defines[@]}"
    local app="$BENCH_DIR/project/mac/spine-bench.app"
    /usr/libexec/PlistBuddy -c "Delete :LSUIElement" "$app/Contents/Info.plist" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$app/Contents/Info.plist"
    mkdir -p "$BENCH_DIR/results/apps"
    local target="$BENCH_DIR/results/apps/$label.app"
    # Replace a previous build with the same label (the label is validated above,
    # so the target is always inside results/apps)
    if [ -e "$target" ]; then
        rm -r "${target:?}"
    fi
    cp -R "$app" "$target"
    codesign --force --sign - --deep "$target" >/dev/null 2>&1
    echo "Built $target"
}

cmd_run() {
    local labels="${1:-}"
    local scenarios="${2:-}"
    local reps="${3:-5}"
    if [ -z "$labels" ] || [ -z "$scenarios" ]; then
        echo "Usage: ./bench.sh run <label,...> <scenario,...> [repetitions]" >&2
        exit 1
    fi
    ensure_guard
    IFS=',' read -r -a label_list <<< "$labels"
    IFS=',' read -r -a scenario_list <<< "$scenarios"
    for scenario in "${scenario_list[@]}"; do
        for rep in $(seq 1 "$reps"); do
            for label in "${label_list[@]}"; do
                local bin="$BENCH_DIR/results/apps/$label.app/Contents/MacOS/spine-bench"
                if [ ! -x "$bin" ]; then
                    echo "Missing build: $label (run ./bench.sh build first)" >&2
                    exit 1
                fi
                mkdir -p "$BENCH_DIR/results/$label"
                local log="$BENCH_DIR/results/$label/$scenario.log"
                if [ "${SPINE_BENCH_CONTROL:-0}" = "1" ]; then
                    log="$BENCH_DIR/results/$label/$scenario-control.log"
                fi
                echo "== $scenario / $label / run $rep"
                echo "RUN $rep" >> "$log"
                local status=0
                SPINE_BENCH_SCENARIO="$scenario" "$GUARD" "$bin" > "$BENCH_DIR/results/last-run.log" 2>&1 || status=$?
                grep "BENCH" "$BENCH_DIR/results/last-run.log" | sed 's/^.*BENCH/BENCH/' | tee -a "$log"
                if [ "$status" != "0" ]; then
                    echo "Run failed with status $status (see results/last-run.log)" >&2
                    exit 1
                fi
            done
        done
    done
}

case "${1:-}" in
    build) shift; cmd_build "$@" ;;
    run) shift; cmd_run "$@" ;;
    *) echo "Usage: ./bench.sh build <legacy|default> [label] | run <label,...> <scenario,...> [repetitions]" >&2; exit 1 ;;
esac
