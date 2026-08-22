#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
rollback_dir="$work_dir/rollback"
dnf_cache_dir="$work_dir/dnf-cache"
dnf_log_dir="$work_dir/dnf-log"
manifest="$rollback_dir/installed-before.txt"
features_manifest="$rollback_dir/experimental-features-before.txt"
shell_manifest="$rollback_dir/gnome-shell-before.txt"

mkdir -p "$rollback_dir" "$dnf_cache_dir" "$dnf_log_dir"
installed_release=$(rpm -q --qf '%{RELEASE}' mutter)
if [[ "$installed_release" == *'.gwa'* ]]; then
    if [[ -s "$manifest" && -s "$features_manifest" &&
          -s "$shell_manifest" ]]; then
        printf 'Preserving the existing pre-patch rollback snapshot in %s\n' \
            "$rollback_dir"
        exit 0
    fi
    printf 'Patched Mutter is installed but no complete pre-patch snapshot exists.\n' >&2
    printf 'Use recover-official.sh instead of creating a rollback snapshot now.\n' >&2
    exit 1
fi

rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n' 'mutter*' | sort >"$manifest"
gsettings get org.gnome.mutter experimental-features >"$features_manifest"
rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
    gnome-shell >"$shell_manifest"

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
printf 'Cached the exact GNOME Shell baseline in %s\n' "$shell_manifest"
