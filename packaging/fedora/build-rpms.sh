#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
top_dir="$work_dir/rpmbuild"
spec_path=$("$repo_dir/packaging/fedora/prepare-rpmbuild.sh" "${1:-}")
metadata_path="$work_dir/build-metadata.txt"

rpmbuild -ba --define "_topdir $top_dir" "$spec_path"

source_nevra=$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.src\n' \
    "$top_dir"/SRPMS/mutter-*.src.rpm)
upstream_source_rpm=$(<"$work_dir/upstream-source-rpm.txt")
installed_nevra=$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' mutter)
repo_commit=$(git -C "$repo_dir" rev-parse HEAD)

{
    printf 'source_rpm=%s\n' "$source_nevra"
    printf 'upstream_source_rpm=%s\n' "$upstream_source_rpm"
    printf 'installed_baseline=%s\n' "$installed_nevra"
    printf 'repository_commit=%s\n' "$repo_commit"
    printf 'fedora=%s\n' "$(rpm -E '%{fedora}')"
    printf 'built_at=%s\n' "$(date --iso-8601=seconds)"
    sha256sum "$repo_dir"/mutter-patches/[0-9][0-9][0-9][0-9]-*.patch
    find "$top_dir/RPMS" -type f -name '*.rpm' -print0 | sort -z |
        xargs -0 sha256sum
} >"$metadata_path"

printf 'Built RPMs:\n'
find "$top_dir/RPMS" -type f -name '*.rpm' -print | sort
printf 'Build metadata: %s\n' "$metadata_path"
