#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
rollback_dir="$work_dir/rollback"
dnf_cache_dir="$work_dir/dnf-cache"
dnf_log_dir="$work_dir/dnf-log"
manifest="$rollback_dir/installed-before.txt"
features_manifest="$rollback_dir/experimental-features-before.txt"

mkdir -p "$rollback_dir" "$dnf_cache_dir" "$dnf_log_dir"
rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n' 'mutter*' | sort >"$manifest"
gsettings get org.gnome.mutter experimental-features >"$features_manifest"

while read -r name version_release arch; do
    cached_pattern="$rollback_dir/${name}-${version_release}.${arch}.rpm"
    if ! compgen -G "$cached_pattern" >/dev/null; then
        dnf5 --setopt="cachedir=$dnf_cache_dir" --setopt="logdir=$dnf_log_dir" \
            download --destdir="$rollback_dir" \
            "${name}-${version_release}.${arch}"
    fi
done <"$manifest"

printf 'Cached the exact installed Mutter RPM set in %s\n' "$rollback_dir"
printf 'Cached the exact experimental feature list in %s\n' "$features_manifest"
