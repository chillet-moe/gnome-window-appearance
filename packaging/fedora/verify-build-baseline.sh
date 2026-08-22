#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
metadata="$repo_dir/_build/fedora/build-metadata.txt"

if [[ ! -s "$metadata" ]]; then
    printf 'Build metadata does not exist: %s\n' "$metadata" >&2
    exit 1
fi

expected_shell=$(sed -n 's/^gnome_shell_baseline=//p' "$metadata")
if [[ -z "$expected_shell" ]]; then
    printf 'Build metadata lacks a GNOME Shell baseline; rebuild the RPMs.\n' >&2
    exit 1
fi

current_shell=$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
    gnome-shell)
if [[ "$current_shell" != "$expected_shell" ]]; then
    printf 'The patched Mutter build was not tested with this GNOME Shell.\n' >&2
    printf 'Built with: %s\nCurrent:    %s\n' \
        "$expected_shell" "$current_shell" >&2
    printf 'Recover the official stack, rebuild, and rerun the nested tests.\n' >&2
    exit 1
fi

printf 'GNOME Shell matches the patched Mutter build baseline: %s\n' \
    "$current_shell"
