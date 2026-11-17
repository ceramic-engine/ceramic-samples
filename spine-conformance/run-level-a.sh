#!/bin/bash
# Level A conformance: the spine-haxe runtime (built with the flags of a Ceramic app,
# inside the conformance app) against the official reference runtime (spine-libgdx),
# on generated scenarios (mixing, additive tracks, queued animations, skins).
#
# Usage: ./run-level-a.sh [data-dir]      (default: data-43)
#
# Requires Java 21 and Gradle. No window is ever shown (see run.sh).
set -eu
cd "$(dirname "$0")"
DIR="$(pwd)"
DATA="${1:-data-43}"
DATA_ABS="$(cd "$DATA" && pwd)"
RESULTS="$DIR/results"
SCENARIOS="$RESULTS/scenarios"
JAVA_OUT="$RESULTS/level-a-java"
HAXE_OUT="$RESULTS/level-a-haxe"
GUARD="$RESULTS/bin/window-guard"

mkdir -p "$RESULTS/bin"
if [ ! -x "$GUARD" ] || [ "tools/window-guard.swift" -nt "$GUARD" ]; then
    swiftc -O -o "$GUARD" tools/window-guard.swift
fi

python3 -I tools/make-scenarios.py "$DATA_ABS" "$SCENARIOS"

# Reference (Java)
(cd reference-java && gradle --no-daemon -q runnerJar -PbuildDir=../results/reference-java-build)
mkdir -p "$JAVA_OUT"
"$GUARD" "$(command -v java)" -Djava.awt.headless=true -jar "$RESULTS/reference-java-build/libs/scenario-runner.jar" "$DATA_ABS" "$SCENARIOS" "$JAVA_OUT"

# spine-haxe, inside the Ceramic app
SPINE_CONFORMANCE_LEVEL_A="$SCENARIOS" ./run.sh default "$HAXE_OUT"

SPINE_CONFORMANCE_DATA="$DATA_ABS" python3 -I compare/compare_level_a.py "$HAXE_OUT" "$JAVA_OUT" "$RESULTS/level-a-report.md"
