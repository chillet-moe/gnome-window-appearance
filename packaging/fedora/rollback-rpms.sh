#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
rollback_dir="$work_dir/rollback"
dnf_log_dir="$work_dir/dnf-log"
manifest="$rollback_dir/installed-before.txt"
rollback_rpms=()

if [[ ! -s "$manifest" ]]; then
    printf 'Rollback manifest does not exist: %s\n' "$manifest" >&2
    exit 1
fi

while read -r name version_release arch; do
    rpm_path=$(find "$rollback_dir" -maxdepth 1 -type f \
        -name "${name}-${version_release}.${arch}.rpm" -print -quit)
    if [[ -z "$rpm_path" ]]; then
        printf 'Cached rollback RPM is missing for %s-%s.%s\n' \
            "$name" "$version_release" "$arch" >&2
        exit 1
    fi
    rollback_rpms+=("$rpm_path")
done <"$manifest"

sudo dnf5 --setopt="logdir=$dnf_log_dir" --disablerepo='*' downgrade \
    "${rollback_rpms[@]}"

current_features=$(gsettings get org.gnome.mutter experimental-features)
if [[ "$current_features" == *"'window-appearance'"* ]]; then
    new_features=$(sed -E \
        "s/'window-appearance',[[:space:]]*//; s/,[[:space:]]*'window-appearance'//; s/'window-appearance'//" \
        <<<"$current_features")
    if [[ "$new_features" == '[]' ]]; then
        new_features='@as []'
    fi
    gsettings set org.gnome.mutter experimental-features "$new_features"
fi

printf 'Restored the pre-install Mutter RPM set. Log out and back in to load it.\n'
