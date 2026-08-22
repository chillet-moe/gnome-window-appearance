#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build_dir=$("$repo_dir/scripts/build-mutter.sh" "${1:-}")

test -f "$build_dir/src/libmutter-18.so.0.0.0"
test -f "$build_dir/clutter/clutter/libmutter-clutter-18.so.0.0.0"
test -f "$build_dir/cogl/cogl/libmutter-cogl-18.so.0.0.0"
test -f "$build_dir/mtk/mtk/libmutter-mtk-18.so.0.0.0"

printf 'Mutter patch stack applied and libmutter compiled successfully: %s\n' \
    "$build_dir/src/libmutter-18.so.0.0.0"
