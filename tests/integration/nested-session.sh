#!/usr/bin/env bash
set -euo pipefail

uuid=gnome-window-appearance@chillet.moe
shell_log="$TEST_ARTIFACT_DIR/gnome-shell.log"
screenshot="$TEST_ARTIFACT_DIR/fractional-2.5.png"
display_config="$TEST_ARTIFACT_DIR/display-config.txt"
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
    printf 'Nested GNOME Shell did not finish startup. Shell log:\n' >&2
    tail -n 120 "$shell_log" >&2
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
    printf 'Nested monitor did not enter 250%% scale. Configuration:\n' >&2
    cat "$display_config" >&2
    exit 1
fi

gnome-extensions enable "$uuid"
sleep 0.5

GDK_BACKEND=wayland WAYLAND_DISPLAY="$TEST_WAYLAND_DISPLAY" \
    "$TEST_PROBE" &
probe_pid=$!

for _ in $(seq 1 100); do
    if rg -q '\[gnome-window-appearance\] mask ' "$shell_log"; then
        break
    fi
    sleep 0.1
done

if ! rg -q '\[gnome-window-appearance\] enabled' "$shell_log"; then
    printf 'Extension did not enable. Shell log:\n' >&2
    tail -n 120 "$shell_log" >&2
    exit 1
fi

if ! rg -q '\[gnome-window-appearance\] mask .*surface-scale=3\.00x3\.00 resource-scale=3\.00 content-opacity=254' "$shell_log"; then
    printf 'Extension did not create a window mask. Shell log:\n' >&2
    tail -n 120 "$shell_log" >&2
    exit 1
fi

for _ in $(seq 1 100); do
    if [[ -s "$screenshot" ]] &&
       rg -q '\[gnome-window-appearance\] test capture ' "$shell_log"; then
        break
    fi
    sleep 0.1
done

if [[ ! -s "$screenshot" ]]; then
    printf 'Nested Shell did not produce the 250%% screenshot. Shell log:\n' >&2
    tail -n 120 "$shell_log" >&2
    exit 1
fi

mask_line=$(rg '\[gnome-window-appearance\] mask .*surface-scale=3\.00x3\.00' \
    "$shell_log" | tail -n 1)
read -r logical_x logical_y logical_width logical_height < <(
    sed -E \
        's/.*frame=([0-9]+)x([0-9]+) frame-position=([0-9]+),([0-9]+).*/\3 \4 \1 \2/' \
        <<<"$mask_line"
)
read -r x1 y1 x2 y2 < <(
    awk -v x="$logical_x" -v y="$logical_y" \
        -v width="$logical_width" -v height="$logical_height" \
        'BEGIN {
            printf "%d %d %d %d\n",
                int(x * 2.5 + 0.5), int(y * 2.5 + 0.5),
                int((x + width) * 2.5 + 0.5) - 1,
                int((y + height) * 2.5 + 0.5) - 1
        }'
)

# The deterministic background is dark blue and the probe edges are nearly
# white. All four corner pixels must expose the background while pixels just
# past the 40 physical-pixel radius must remain window content.
visual_ok=$(magick "$screenshot" -format "%[fx:
    p{$((x1 + 2)),$((y1 + 2))}.r < 0.75 &&
    p{$((x2 - 2)),$((y1 + 2))}.r < 0.75 &&
    p{$((x1 + 2)),$((y2 - 2))}.r < 0.75 &&
    p{$((x2 - 2)),$((y2 - 2))}.r < 0.75 &&
    p{$((x1 + 50)),$((y1 + 2))}.r > 0.85 &&
    p{$((x2 - 50)),$((y1 + 2))}.r > 0.85 &&
    p{$((x1 + 50)),$((y2 - 2))}.r > 0.85 &&
    p{$((x2 - 50)),$((y2 - 2))}.r > 0.85 ? 1 : 0]" info:)
if [[ "$visual_ok" != 1 ]]; then
    printf 'The 250%% screenshot failed the four-corner pixel check.\n' >&2
    exit 1
fi

gnome-extensions disable "$uuid"
for _ in $(seq 1 50); do
    if rg -q '\[gnome-window-appearance\] disabled' "$shell_log"; then
        break
    fi
    sleep 0.1
done
if ! rg -q '\[gnome-window-appearance\] disabled' "$shell_log"; then
    printf 'Extension did not disable cleanly. Shell log:\n' >&2
    tail -n 120 "$shell_log" >&2
    exit 1
fi

if rg -q 'JS ERROR' "$shell_log"; then
    printf 'Extension raised a JavaScript error. Shell log:\n' >&2
    rg -n 'JS ERROR|gnome-window-appearance' "$shell_log" >&2
    exit 1
fi

printf 'Nested GNOME Shell 250%% test passed. Log: %s Screenshot: %s\n' \
    "$shell_log" "$screenshot"
