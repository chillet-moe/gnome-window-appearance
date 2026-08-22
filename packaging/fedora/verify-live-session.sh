#!/usr/bin/env bash
set -euo pipefail

expected_release=${GWA_RPM_RELEASE_TAG:-gwa1}
library=/usr/lib64/libmutter-18.so.0.0.0

for package in mutter mutter-common mutter-devel mutter-devkit; do
    release=$(rpm -q --qf '%{RELEASE}' "$package")
    if [[ "$release" != *".$expected_release."* &&
          "$release" != *".$expected_release" ]]; then
        printf '%s does not have the expected local release tag: %s\n' \
            "$package" "$release" >&2
        exit 1
    fi
done

if ! rpm -V mutter mutter-common mutter-devel mutter-devkit; then
    printf 'Installed Mutter packages failed RPM verification.\n' >&2
    exit 1
fi

features=$(gsettings get org.gnome.mutter experimental-features)
if [[ "$features" != *"'window-appearance'"* ]]; then
    printf 'window-appearance is not enabled: %s\n' "$features" >&2
    exit 1
fi

shell_pid=$(pgrep -n -x gnome-shell || true)
if [[ -z "$shell_pid" ]]; then
    printf 'No running GNOME Shell process was found.\n' >&2
    exit 1
fi

map_line=$(rg -m1 -F "$library" "/proc/$shell_pid/maps" || true)
if [[ -z "$map_line" || "$map_line" == *' (deleted)' ]]; then
    printf 'GNOME Shell has not loaded the installed Mutter library: %s\n' \
        "${map_line:-missing}" >&2
    exit 1
fi

mapped_inode=$(awk '{ print $5 }' <<<"$map_line")
installed_inode=$(stat -c '%i' "$library")
if [[ "$mapped_inode" != "$installed_inode" ]]; then
    printf 'Mapped and installed Mutter inode differ: %s != %s\n' \
        "$mapped_inode" "$installed_inode" >&2
    exit 1
fi

shell_log=$(journalctl --user -b "_PID=$shell_pid" --no-pager)
if rg -qi 'segmentation fault|assertion.*failed|failed to create backend' \
    <<<"$shell_log"; then
    printf 'GNOME Shell startup log contains a fatal error.\n' >&2
    exit 1
fi

printf 'Live GNOME Shell %s maps the installed patched Mutter inode %s.\n' \
    "$shell_pid" "$installed_inode"
printf 'Experimental features: %s\n' "$features"
