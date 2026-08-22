#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_dir=$("$repo_dir/scripts/prepare-mutter-source.sh" "${1:-}")
build_dir="$repo_dir/_build/mutter/build"

setup_mode=()
if [[ -f "$build_dir/meson-private/coredata.dat" ]]; then
    setup_mode+=(--wipe)
fi

meson setup "$build_dir" "$source_dir" "${setup_mode[@]}" \
    -Dbuildtype=debug \
    -Dtests=enabled \
    -Dxwayland=true \
    -Ddocs=false \
    -Dprofiler=false >&2
ninja -C "$build_dir" src/libmutter-18.so.0.0.0 >&2

printf '%s\n' "$build_dir"
