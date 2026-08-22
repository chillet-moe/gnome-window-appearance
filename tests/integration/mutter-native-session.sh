#!/usr/bin/env bash
set -euo pipefail

uuid=gnome-window-appearance@chillet.moe
shell_log="$TEST_ARTIFACT_DIR/mutter-native-shell.log"
screenshot="$TEST_ARTIFACT_DIR/fractional-2.5.png"
display_config="$TEST_ARTIFACT_DIR/mutter-native-display-config.txt"
rm -f "$screenshot"

gsettings set org.gnome.shell enabled-extensions "['$uuid']"
gsettings set org.gnome.shell disable-user-extensions false
gsettings set org.gnome.desktop.background picture-uri ''
gsettings set org.gnome.desktop.background picture-uri-dark ''
gsettings set org.gnome.desktop.background color-shading-type 'solid'
gsettings set org.gnome.desktop.background primary-color '#204060'
gnome-shell \
    --wayland \
    --headless \
    --virtual-monitor=3200x1800 \
    --no-x11 \
    --wayland-display="$TEST_WAYLAND_DISPLAY" \
    --force-animations \
    --debug-control \
    >"$shell_log" 2>&1 &
shell_pid=$!

probe_pid=
cleanup() {
    if [[ -n "$probe_pid" ]]; then
        kill "$probe_pid" 2>/dev/null || true
    fi
    kill "$shell_pid" 2>/dev/null || true
    wait "$shell_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 100); do
    if [[ -S "$XDG_RUNTIME_DIR/$TEST_WAYLAND_DISPLAY" ]] &&
       rg -q 'GNOME Shell started' "$shell_log"; then
        break
    fi
    sleep 0.1
done

if ! rg -q 'GNOME Shell started' "$shell_log"; then
    printf 'Patched nested GNOME Shell did not finish startup.\n' >&2
    tail -n 120 "$shell_log" >&2
    exit 1
fi

if ! rg -q "$TEST_MUTTER_BUILD_DIR/src/libmutter-18" "/proc/$shell_pid/maps"; then
    printf 'Nested GNOME Shell did not load the patched libmutter.\n' >&2
    exit 1
fi
gdctl set \
    --layout-mode logical \
    --logical-monitor \
    --primary \
    --scale 2.5 \
    --monitor Meta-0
gdctl show >"$display_config"
if ! rg -q 'Scale: 2\.5' "$display_config"; then
    printf 'Nested monitor did not enter 250%% scale.\n' >&2
    exit 1
fi

gnome-extensions enable "$uuid"
GDK_BACKEND=wayland WAYLAND_DISPLAY="$TEST_WAYLAND_DISPLAY" \
    "$TEST_PROBE" &
probe_pid=$!

for _ in $(seq 1 120); do
    if [[ -s "$screenshot" ]] &&
       rg -q '\[gnome-window-appearance\] capture-only window-probe ' "$shell_log"; then
        break
    fi
    sleep 0.1
done

if [[ ! -s "$screenshot" ]]; then
    printf 'Patched nested Shell did not produce a screenshot.\n' >&2
    tail -n 120 "$shell_log" >&2
    exit 1
fi

geometry_line=$(rg '\[gnome-window-appearance\] capture-only window-probe ' \
    "$shell_log" | tail -n 1)
if [[ "$geometry_line" != *'native-clip=true'* ]]; then
    printf 'Wayland surface container did not receive the native clip: %s\n' \
        "$geometry_line" >&2
    exit 1
fi
read -r frame_width frame_height frame_x frame_y \
    buffer_width buffer_height buffer_x buffer_y < <(
    sed -E \
        's/.*frame=([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+) buffer=([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+).*/\1 \2 \3 \4 \5 \6 \7 \8/' \
        <<<"$geometry_line"
)

read -r sample_x sample_y extent < <(
    awk \
        -v fx="$frame_x" -v fy="$frame_y" \
        -v fw="$frame_width" -v fh="$frame_height" \
        -v bx="$buffer_x" -v by="$buffer_y" \
        -v bw="$buffer_width" -v bh="$buffer_height" \
        'BEGIN {
            left = fx - bx
            top = fy - by
            right = bx + bw - fx - fw
            bottom = by + bh - fy - fh
            extent = left
            x = fx - left / 2
            y = fy + fh / 2
            if (top > extent) {
                extent = top
                x = fx + fw / 2
                y = fy - top / 2
            }
            if (right > extent) {
                extent = right
                x = fx + fw + right / 2
                y = fy + fh / 2
            }
            if (bottom > extent) {
                extent = bottom
                x = fx + fw / 2
                y = fy + fh + bottom / 2
            }
            printf "%d %d %d\n", int(x * 2.5 + 0.5), int(y * 2.5 + 0.5), extent
        }'
)
if (( extent < 2 )); then
    printf 'Probe did not expose distinct frame and buffer geometry: %s\n' \
        "$geometry_line" >&2
    exit 1
fi

# The sample lies inside the client buffer but outside its declared frame. The
# native container clip must reveal the deterministic #204060 background.
background_ok=$(magick "$screenshot" -format "%[fx:
    abs(p{$sample_x,$sample_y}.r - 32/255) < 0.05 &&
    abs(p{$sample_x,$sample_y}.g - 64/255) < 0.05 &&
    abs(p{$sample_x,$sample_y}.b - 96/255) < 0.05 ? 1 : 0]" info:)
if [[ "$background_ok" != 1 ]]; then
    printf 'Client shadow remained outside the declared frame at %s,%s.\n' \
        "$sample_x" "$sample_y" >&2
    exit 1
fi

if rg -q 'JS ERROR|segmentation fault|assertion.*failed' "$shell_log"; then
    printf 'Patched nested Shell reported an error.\n' >&2
    rg -ni 'JS ERROR|segmentation fault|assertion.*failed' "$shell_log" >&2
    exit 1
fi

printf 'Patched Mutter 250%% nested test passed. Log: %s Screenshot: %s\n' \
    "$shell_log" "$screenshot"
