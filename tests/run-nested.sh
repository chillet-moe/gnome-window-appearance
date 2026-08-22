#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build_dir="$repo_dir/_build/nested"
uuid=gnome-window-appearance@chillet.moe
wayland_display="gwayland-appearance-test-$$"

"$repo_dir/scripts/build-extension.sh" >/dev/null
mkdir -p "$build_dir/bin" "$build_dir/config" "$build_dir/data/gnome-shell/extensions"
mkdir -p "$build_dir/cache" "$build_dir/state" "$repo_dir/tests/artifacts"

cc -O2 -Wall -Wextra \
    "$repo_dir/tests/fixtures/window-probe.c" \
    -o "$build_dir/bin/window-probe" \
    $(pkg-config --cflags --libs gtk+-3.0)

extension_target="$build_dir/data/gnome-shell/extensions/$uuid"
rm -rf "$extension_target"
cp -R "$repo_dir/_build/extension/$uuid" "$extension_target"

export GSETTINGS_BACKEND=keyfile
export XDG_CONFIG_HOME="$build_dir/config"
export XDG_DATA_HOME="$build_dir/data"
export XDG_CACHE_HOME="$build_dir/cache"
export XDG_STATE_HOME="$build_dir/state"
export GTK_A11Y=none
export TEST_WAYLAND_DISPLAY="$wayland_display"
export TEST_PROBE="$build_dir/bin/window-probe"
export TEST_ARTIFACT_DIR="$repo_dir/tests/artifacts"
dbus-run-session -- "$repo_dir/tests/integration/nested-session.sh"
