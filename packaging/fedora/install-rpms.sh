#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
rpm_dir="$work_dir/rpmbuild/RPMS"
rollback_dir="$work_dir/rollback"
dnf_log_dir="$work_dir/dnf-log"
manifest="$rollback_dir/installed-before.txt"
local_rpms=()

"$repo_dir/packaging/fedora/verify-rpms.sh"
"$repo_dir/packaging/fedora/verify-build-baseline.sh"
"$repo_dir/packaging/fedora/cache-rollback.sh"

while read -r name _; do
    while IFS= read -r -d '' rpm_path; do
        if [[ $(rpm -qp --qf '%{NAME}' "$rpm_path") == "$name" ]]; then
            local_rpms+=("$rpm_path")
        fi
    done < <(find "$rpm_dir" -type f -name '*.rpm' -print0)
done <"$manifest"

if [[ ${#local_rpms[@]} -eq 0 ]]; then
    printf 'No locally built RPM matches an installed Mutter subpackage.\n' >&2
    exit 1
fi

sudo dnf5 --setopt="logdir=$dnf_log_dir" --disablerepo='*' install "${local_rpms[@]}"

current_features=$(gsettings get org.gnome.mutter experimental-features)
if [[ "$current_features" != *"'window-appearance'"* ]]; then
    if [[ "$current_features" == '@as []' || "$current_features" == '[]' ]]; then
        new_features="['window-appearance']"
    else
        new_features="${current_features%]}"
        new_features="${new_features}, 'window-appearance']"
    fi
    gsettings set org.gnome.mutter experimental-features "$new_features"
fi

printf 'Installed local Mutter RPMs. Log out and back in to load them.\n'
printf 'Rollback cache: %s\n' "$rollback_dir"
