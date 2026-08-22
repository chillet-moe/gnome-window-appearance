#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_dir="$repo_dir/_build/mutter"
srpm_dir="$work_dir/srpm"
source_dir="$work_dir/source"
srpm_path=${1:-}

if [[ -z "$srpm_path" ]]; then
    source_rpm=$(rpm -q --qf '%{SOURCERPM}\n' mutter)
    srpm_path="$srpm_dir/$source_rpm"
    if [[ ! -f "$srpm_path" ]]; then
        mkdir -p "$srpm_dir" "$work_dir/dnf-cache" "$work_dir/dnf-log"
        dnf5 \
            --setopt="cachedir=$work_dir/dnf-cache" \
            --setopt="logdir=$work_dir/dnf-log" \
            download --source --destdir="$srpm_dir" \
            "${source_rpm%.src.rpm}" >&2
    fi
fi

if [[ ! -f "$srpm_path" ]]; then
    printf 'Mutter source RPM does not exist: %s\n' "$srpm_path" >&2
    exit 1
fi
srpm_path=$(realpath -- "$srpm_path")

rm -rf "$work_dir/extracted" "$source_dir"
mkdir -p "$work_dir/extracted" "$source_dir"
(
    cd "$work_dir/extracted"
    rpm2cpio "$srpm_path" | cpio -idm
)

source_archive=$(find "$work_dir/extracted" -maxdepth 1 -type f \
    \( -name 'mutter-*.tar.xz' -o -name 'mutter-*.tar.gz' \) -print -quit)
if [[ -z "$source_archive" ]]; then
    printf 'Mutter source archive was not found in %s\n' "$srpm_path" >&2
    exit 1
fi

tar -xf "$source_archive" -C "$source_dir" --strip-components=1
for patch_file in "$repo_dir"/mutter-patches/[0-9][0-9][0-9][0-9]-*.patch; do
    patch --directory="$source_dir" --strip=1 --forward <"$patch_file" >&2
done

printf '%s\n' "$source_dir"
