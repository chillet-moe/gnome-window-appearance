#!/usr/bin/env bash
set -euo pipefail

uuid=gnome-window-appearance@chillet.moe
test_wm_class=${GWA_TEST_WM_CLASS:-window-probe}
shell_log="$TEST_ARTIFACT_DIR/mutter-native-shell.log"
screenshot="$TEST_ARTIFACT_DIR/fractional-2.5.png"
maximized_screenshot="$TEST_ARTIFACT_DIR/mutter-native-maximized.png"
restored_screenshot="$TEST_ARTIFACT_DIR/mutter-native-restored.png"
fullscreen_screenshot="$TEST_ARTIFACT_DIR/mutter-native-fullscreen.png"
restored_final_screenshot="$TEST_ARTIFACT_DIR/mutter-native-restored-final.png"
display_config="$TEST_ARTIFACT_DIR/mutter-native-display-config.txt"
rm -f "$screenshot" "$maximized_screenshot" "$restored_screenshot" \
    "$fullscreen_screenshot" "$restored_final_screenshot"

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
       [[ -s "$restored_final_screenshot" ]] &&
       rg -q "\[gnome-window-appearance\] capture-only $test_wm_class " "$shell_log"; then
        break
    fi
    sleep 0.1
done

if [[ ! -s "$screenshot" ]]; then
    printf 'Patched nested Shell did not produce a screenshot.\n' >&2
    tail -n 120 "$shell_log" >&2
    exit 1
fi
if [[ ! -s "$maximized_screenshot" || ! -s "$restored_screenshot" ||
      ! -s "$fullscreen_screenshot" || ! -s "$restored_final_screenshot" ]]; then
    printf 'Patched nested Shell did not complete state-transition captures.\n' >&2
    tail -n 120 "$shell_log" >&2
    exit 1
fi

for expected_state in \
    'state=maximized native-clip=false' \
    'state=restored native-clip=true' \
    'state=fullscreen native-clip=false' \
    'state=restored-final native-clip=true'; do
    if ! rg -q "\[gnome-window-appearance\] $expected_state" "$shell_log"; then
        printf 'Native clip state transition was not observed: %s\n' \
            "$expected_state" >&2
        exit 1
    fi
done

for state_capture in \
    "maximized:$maximized_screenshot" \
    "fullscreen:$fullscreen_screenshot"; do
    state=${state_capture%%:*}
    state_screenshot=${state_capture#*:}
    state_line=$(rg "\[gnome-window-appearance\] state=$state " \
        "$shell_log" | tail -n 1)
    read -r state_x state_y < <(
        sed -E \
            's/.*frame=[0-9]+x[0-9]+\+([0-9]+)\+([0-9]+).*/\1 \2/' \
            <<<"$state_line"
    )
    state_sample_x=$(( (state_x + 2) * 5 / 2 ))
    state_sample_y=$(( (state_y + 2) * 5 / 2 ))
    square_corner_visible=$(magick "$state_screenshot" -format "%[fx:
        p{$state_sample_x,$state_sample_y}.r > 0.9 &&
        p{$state_sample_x,$state_sample_y}.g < 0.1 &&
        p{$state_sample_x,$state_sample_y}.b < 0.1 ? 1 : 0]" info:)
    if [[ "$square_corner_visible" != 1 ]]; then
        printf 'Rounded alpha remained active in %s state.\n' "$state" >&2
        exit 1
    fi
done

geometry_line=$(rg "\[gnome-window-appearance\] capture-only $test_wm_class " \
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

# Sample two logical pixels inside each frame corner. A 16px logical native
# radius at 250% scale must expose the background there, while the center must
# remain client content. The latter prevents an all-transparent shader failure
# from masquerading as a successful clip.
read -r top_left_x top_left_y top_right_x top_right_y \
    bottom_left_x bottom_left_y bottom_right_x bottom_right_y \
    center_x center_y < <(
    awk \
        -v fx="$frame_x" -v fy="$frame_y" \
        -v fw="$frame_width" -v fh="$frame_height" \
        'BEGIN {
            scale = 2.5
            inset = 2
            printf "%d %d %d %d %d %d %d %d %d %d\n", \
                int((fx + inset) * scale + 0.5), \
                int((fy + inset) * scale + 0.5), \
                int((fx + fw - inset) * scale + 0.5), \
                int((fy + inset) * scale + 0.5), \
                int((fx + inset) * scale + 0.5), \
                int((fy + fh - inset) * scale + 0.5), \
                int((fx + fw - inset) * scale + 0.5), \
                int((fy + fh - inset) * scale + 0.5), \
                int((fx + fw / 2) * scale + 0.5), \
                int((fy + fh / 2) * scale + 0.5)
        }'
)

rounded_corners_ok=$(magick "$screenshot" -format "%[fx:
    abs(p{$top_left_x,$top_left_y}.r - 32/255) < 0.05 &&
    abs(p{$top_left_x,$top_left_y}.g - 64/255) < 0.05 &&
    abs(p{$top_left_x,$top_left_y}.b - 96/255) < 0.05 &&
    abs(p{$top_right_x,$top_right_y}.r - 32/255) < 0.05 &&
    abs(p{$top_right_x,$top_right_y}.g - 64/255) < 0.05 &&
    abs(p{$top_right_x,$top_right_y}.b - 96/255) < 0.05 &&
    abs(p{$bottom_left_x,$bottom_left_y}.r - 32/255) < 0.05 &&
    abs(p{$bottom_left_x,$bottom_left_y}.g - 64/255) < 0.05 &&
    abs(p{$bottom_left_x,$bottom_left_y}.b - 96/255) < 0.05 &&
    abs(p{$bottom_right_x,$bottom_right_y}.r - 32/255) < 0.05 &&
    abs(p{$bottom_right_x,$bottom_right_y}.g - 64/255) < 0.05 &&
    abs(p{$bottom_right_x,$bottom_right_y}.b - 96/255) < 0.05 ? 1 : 0]" info:)
if [[ "$rounded_corners_ok" != 1 ]]; then
    printf 'Native rounded alpha did not expose all four frame corners.\n' >&2
    exit 1
fi

restored_corners_ok=$(magick "$restored_final_screenshot" -format "%[fx:
    abs(p{$top_left_x,$top_left_y}.r - 32/255) < 0.05 &&
    abs(p{$top_left_x,$top_left_y}.g - 64/255) < 0.05 &&
    abs(p{$top_left_x,$top_left_y}.b - 96/255) < 0.05 &&
    abs(p{$top_right_x,$top_right_y}.r - 32/255) < 0.05 &&
    abs(p{$top_right_x,$top_right_y}.g - 64/255) < 0.05 &&
    abs(p{$top_right_x,$top_right_y}.b - 96/255) < 0.05 &&
    abs(p{$bottom_left_x,$bottom_left_y}.r - 32/255) < 0.05 &&
    abs(p{$bottom_left_x,$bottom_left_y}.g - 64/255) < 0.05 &&
    abs(p{$bottom_left_x,$bottom_left_y}.b - 96/255) < 0.05 &&
    abs(p{$bottom_right_x,$bottom_right_y}.r - 32/255) < 0.05 &&
    abs(p{$bottom_right_x,$bottom_right_y}.g - 64/255) < 0.05 &&
    abs(p{$bottom_right_x,$bottom_right_y}.b - 96/255) < 0.05 ? 1 : 0]" info:)
if [[ "$restored_corners_ok" != 1 ]]; then
    printf 'Native rounded alpha was not restored after state transitions.\n' >&2
    exit 1
fi

if [[ "$test_wm_class" == subsurface-probe ]]; then
    subsurface_x=$(( (frame_x + 16) * 5 / 2 ))
    subsurface_y=$(( (frame_y + 2) * 5 / 2 ))
    subsurface_visible=$(magick "$screenshot" -format "%[fx:
        p{$subsurface_x,$subsurface_y}.r > 0.9 &&
        p{$subsurface_x,$subsurface_y}.g < 0.1 &&
        p{$subsurface_x,$subsurface_y}.b < 0.1 ? 1 : 0]" info:)
    if [[ "$subsurface_visible" != 1 ]]; then
        printf 'Subsurface probe was not visible inside the rounded boundary.\n' >&2
        exit 1
    fi
fi

content_visible=$(magick "$screenshot" -format "%[fx:
    abs(p{$center_x,$center_y}.r - 32/255) >= 0.05 ||
    abs(p{$center_x,$center_y}.g - 64/255) >= 0.05 ||
    abs(p{$center_x,$center_y}.b - 96/255) >= 0.05 ? 1 : 0]" info:)
if [[ "$content_visible" != 1 ]]; then
    printf 'Window content disappeared while applying native rounded alpha.\n' >&2
    exit 1
fi

if rg -q 'JS ERROR|segmentation fault|assertion.*failed' "$shell_log"; then
    printf 'Patched nested Shell reported an error.\n' >&2
    rg -ni 'JS ERROR|segmentation fault|assertion.*failed' "$shell_log" >&2
    exit 1
fi

printf 'Patched Mutter 250%% nested test passed. Log: %s Screenshot: %s\n' \
    "$shell_log" "$screenshot"
