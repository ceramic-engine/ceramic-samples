#!/bin/bash
# Build the spine-cpp reference dumper and dump every animation of every skeleton
# of a data set (data-43) into <output-dir>/<skeleton>/<animation>.json
#
# Usage: reference-cpp/run-reference.sh <data-dir> <output-dir> [fps]
set -eu

cd "$(dirname "$0")"
REF_DIR="$(pwd)"
DATA="${1:-}"
OUT="${2:-}"
FPS="${3:-30}"
if [ -z "$DATA" ] || [ -z "$OUT" ] || [ ! -d "$DATA" ]; then
    echo "Usage: reference-cpp/run-reference.sh <data-dir> <output-dir>" >&2
    exit 1
fi

BUILD="$REF_DIR/../results/reference-cpp-build"
mkdir -p "$BUILD"
cmake -S "$REF_DIR" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release > /dev/null
cmake --build "$BUILD" -j 8 > /dev/null
DUMP="$BUILD/spine-reference-dump"

mkdir -p "$OUT"
for folder in "$DATA"/*.spine; do
    skeleton="$(basename "$folder" .spine)"
    json="$folder/$skeleton.json"
    atlas="$(ls "$folder"/*.atlas | head -1)"
    mkdir -p "$OUT/$skeleton"
    python3 -I -c 'import json,sys; [print(n) for n in sorted(json.load(open(sys.argv[1]))["animations"].keys())]' "$json" | while IFS= read -r animation; do
        safe="$(printf '%s' "$animation" | tr -c 'a-zA-Z0-9_-' '_')"
        "$DUMP" "$json" "$atlas" "$animation" "$OUT/$skeleton/$safe.json" "$FPS"
    done
    echo "Reference: $skeleton"
done
