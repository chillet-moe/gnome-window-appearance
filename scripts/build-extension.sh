#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
uuid=gnome-window-appearance@chillet.moe
output_dir="$repo_dir/_build/extension/$uuid"

mkdir -p "$output_dir"
cp -R "$repo_dir/extension/." "$output_dir/"
glib-compile-schemas --strict "$output_dir/schemas"

printf '%s\n' "$output_dir"
