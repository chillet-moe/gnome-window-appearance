#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
update_dir="$work_dir/updates"
dnf_cache_dir="$work_dir/dnf-cache"
dnf_log_dir="$work_dir/dnf-log"
metadata_path="$work_dir/build-metadata.txt"
arch=$(uname -m)

mkdir -p "$update_dir" "$dnf_cache_dir" "$dnf_log_dir"
latest_source_rpm=$(dnf5 --quiet \
    --setopt="cachedir=$dnf_cache_dir" --setopt="logdir=$dnf_log_dir" \
    repoquery --available --arch="$arch" --latest-limit=1 \
    --queryformat '%{sourcerpm}' mutter)

if [[ -z "$latest_source_rpm" ]]; then
    printf 'No available Mutter source package was found.\n' >&2
    exit 1
fi

current_source_rpm=''
if [[ -f "$metadata_path" ]]; then
    current_source_rpm=$(sed -n 's/^upstream_source_rpm=//p' "$metadata_path")
fi
if [[ -z "$current_source_rpm" ]]; then
    current_source_rpm=$(rpm -q --qf '%{SOURCERPM}\n' mutter)
fi

if [[ "$latest_source_rpm" == "$current_source_rpm" ]]; then
    printf 'No Mutter source update: %s\n' "$current_source_rpm"
    exit 0
fi

printf 'Rebuilding for Mutter update: %s -> %s\n' \
    "$current_source_rpm" "$latest_source_rpm"
rm -f "$update_dir/$latest_source_rpm"
dnf5 --setopt="cachedir=$dnf_cache_dir" --setopt="logdir=$dnf_log_dir" \
    download --source --destdir="$update_dir" "${latest_source_rpm%.src.rpm}"

srpm_path="$update_dir/$latest_source_rpm"
"$repo_dir/scripts/test-mutter-patches.sh" "$srpm_path"
"$repo_dir/tests/run-mutter-nested.sh"
"$repo_dir/packaging/fedora/build-rpms.sh" "$srpm_path"
"$repo_dir/packaging/fedora/verify-rpms.sh"

printf 'Update rebuilt and tested; it was not installed automatically.\n'
