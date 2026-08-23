#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build_dir="$repo_dir/_build/mutter/build"
library_dir=${TEST_MUTTER_LIBRARY_DIR:-$build_dir/src}
runtime_dir="$repo_dir/_build/mutter/nested"
artifact_dir=${GWA_TEST_ARTIFACT_DIR:-$repo_dir/tests/artifacts}
uuid=gnome-window-appearance@chillet.moe
wayland_display="gwayland-mutter-appearance-test-$$"

required_libraries=("$library_dir/libmutter-18.so.0.0.0")
if [[ -z ${TEST_MUTTER_LIBRARY_DIR:-} ]]; then
    required_libraries+=(
        "$build_dir/clutter/clutter/libmutter-clutter-18.so.0.0.0"
        "$build_dir/cogl/cogl/libmutter-cogl-18.so.0.0.0"
        "$build_dir/mtk/mtk/libmutter-mtk-18.so.0.0.0"
    )
fi
for library in "${required_libraries[@]}"; do
    if [[ ! -f "$library" ]]; then
        printf 'Patched Mutter is not built; run scripts/test-mutter-patches.sh first.\n' >&2
        exit 1
    fi
done

"$repo_dir/scripts/build-extension.sh" >/dev/null
mkdir -p "$runtime_dir/bin" "$runtime_dir/config" "$runtime_dir/data/gnome-shell/extensions"
mkdir -p "$runtime_dir/cache" "$runtime_dir/state" "$artifact_dir"

read -r -a gtk_flags <<<"$(pkg-config --cflags --libs gtk+-3.0)"
cc -O2 -Wall -Wextra \
    "$repo_dir/tests/fixtures/window-probe.c" \
    -o "$runtime_dir/bin/window-probe" \
    "${gtk_flags[@]}"

xdg_shell_xml=$(pkg-config --variable=pkgdatadir wayland-protocols)/stable/xdg-shell/xdg-shell.xml
wayland-scanner client-header \
    "$xdg_shell_xml" \
    "$runtime_dir/bin/xdg-shell-client-protocol.h"
wayland-scanner private-code \
    "$xdg_shell_xml" \
    "$runtime_dir/bin/xdg-shell-protocol.c"
read -r -a wayland_flags <<<"$(pkg-config --cflags --libs wayland-client)"
cc -O2 -Wall -Wextra -Wno-unused-parameter \
    -I"$runtime_dir/bin" \
    "$repo_dir/tests/fixtures/subsurface-probe.c" \
    "$runtime_dir/bin/xdg-shell-protocol.c" \
    -o "$runtime_dir/bin/subsurface-probe" \
    "${wayland_flags[@]}"

extension_target="$runtime_dir/data/gnome-shell/extensions/$uuid"
rm -rf "$extension_target"
cp -R "$repo_dir/_build/extension/$uuid" "$extension_target"

export GSETTINGS_BACKEND=keyfile
export XDG_CONFIG_HOME="$runtime_dir/config"
export XDG_DATA_HOME="$runtime_dir/data"
export XDG_CACHE_HOME="$runtime_dir/cache"
export XDG_STATE_HOME="$runtime_dir/state"
export GTK_A11Y=none
export TEST_WAYLAND_DISPLAY="$wayland_display"
export TEST_PROBE="$runtime_dir/bin/subsurface-probe"
export TEST_ARTIFACT_DIR="$artifact_dir"
export TEST_MUTTER_LIBRARY_DIR="$library_dir"
export GWA_TEST_CAPTURE_ONLY=1
export GWA_TEST_WM_CLASS=subsurface-probe
export GWA_TEST_STATE_TRANSITIONS=1
export GWA_TEST_SCALE=${GWA_TEST_SCALE:-2.5}
export MUTTER_DEBUG_EXPERIMENTAL_FEATURES=window-appearance
# GNOME Shell's installed typelibs are paired with the system Cogl, Clutter and
# MTK libraries. Only override the ABI-compatible core libmutter containing the
# patch; loading build-tree copies of the component libraries as well would
# register their boxed GI types a second time.
export LD_LIBRARY_PATH="$library_dir"

"$repo_dir/tests/lib/run-isolated-session.sh" \
    dbus-run-session -- "$repo_dir/tests/integration/mutter-native-session.sh"
