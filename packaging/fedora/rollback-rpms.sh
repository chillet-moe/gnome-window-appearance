#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
rollback_dir="$work_dir/rollback"
dnf_log_dir="$work_dir/dnf-log"
manifest="$rollback_dir/installed-before.txt"
features_manifest="$rollback_dir/experimental-features-before.txt"
shell_manifest="$rollback_dir/gnome-shell-before.txt"
rollback_rpms=()

if [[ ! -s "$manifest" ]]; then
    printf 'Rollback manifest does not exist: %s\n' "$manifest" >&2
    exit 1
fi
if [[ ! -s "$features_manifest" ]]; then
    printf 'Rollback feature manifest does not exist: %s\n' \
        "$features_manifest" >&2
    exit 1
fi
if [[ ! -s "$shell_manifest" ]]; then
    printf 'Rollback GNOME Shell manifest does not exist: %s\n' \
        "$shell_manifest" >&2
    exit 1
fi

cached_shell=$(<"$shell_manifest")
current_shell=$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
    gnome-shell)
if [[ "$current_shell" != "$cached_shell" ]]; then
    printf 'Refusing an offline rollback across a GNOME Shell update.\n' >&2
    printf 'Cached:  %s\nCurrent: %s\n' "$cached_shell" "$current_shell" >&2
    printf 'Run packaging/fedora/recover-official.sh to synchronize the current official stack.\n' >&2
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

original_features=$(<"$features_manifest")
gsettings set org.gnome.mutter experimental-features "$original_features"

printf 'Restored the pre-install Mutter RPM set. Log out and back in to load it.\n'
