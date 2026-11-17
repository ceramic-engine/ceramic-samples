#!/bin/bash
# Spine runtime only benchmark on JS (node), legacy (spine-hx) versus spine-haxe.
# Same defines as a Ceramic web build: spine_no_inline for the legacy runtime.
#
# Usage: runtime/run-js.sh <skeleton> <animation> <count> <frames> [repetitions]
set -eu
cd "$(dirname "$0")"
DIR="$(pwd)"
CERAMIC_ROOT="$DIR/../../../ceramic"
HAXE="$CERAMIC_ROOT/git/haxe-binary/mac/haxe/haxe"
SKELETON="${1:?skeleton}"
ANIMATION="${2:?animation}"
COUNT="${3:?count}"
FRAMES="${4:?frames}"
REPS="${5:-3}"
mkdir -p "$DIR/out"
"$HAXE" -cp "$DIR" -cp "$CERAMIC_ROOT/git/spine-hx" -cp "$CERAMIC_ROOT/git/hxnodejs/src" -D hxnodejs --macro "allowPackage('sys')" --macro "define('nodejs')" -D spine_legacy -D spine_no_inline \
    -D analyzer-optimize -dce full -main RuntimeBench -js "$DIR/out/runtime-legacy.js"
"$HAXE" -cp "$DIR" -cp "$CERAMIC_ROOT/git/spine-runtimes/spine-haxe/spine-haxe" -cp "$CERAMIC_ROOT/git/hxnodejs/src" -D hxnodejs --macro "allowPackage('sys')" --macro "define('nodejs')" \
    -D analyzer-optimize -dce full -main RuntimeBench -js "$DIR/out/runtime-spine43.js"
for rep in $(seq 1 "$REPS"); do
    echo "== run $rep"
    node "$DIR/out/runtime-legacy.js" "$DIR/../../spine-conformance/data-40" "$SKELETON" "$ANIMATION" "$COUNT" "$FRAMES" | grep BENCH
    node "$DIR/out/runtime-spine43.js" "$DIR/../../spine-conformance/data-43" "$SKELETON" "$ANIMATION" "$COUNT" "$FRAMES" | grep BENCH
done
