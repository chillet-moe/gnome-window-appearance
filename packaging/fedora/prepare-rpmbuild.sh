#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
top_dir="$work_dir/rpmbuild"
input_dir="$work_dir/input"
srpm_path=${1:-}
release_tag=${GWA_RPM_RELEASE_TAG:-gwa1}

if [[ ! "$release_tag" =~ ^[A-Za-z0-9]+$ ]]; then
    printf 'GWA_RPM_RELEASE_TAG must be alphanumeric: %s\n' "$release_tag" >&2
    exit 1
fi

if [[ -z "$srpm_path" ]]; then
    source_rpm=$(rpm -q --qf '%{SOURCERPM}\n' mutter)
    srpm_path="$repo_dir/_build/mutter/srpm/$source_rpm"
    if [[ ! -f "$srpm_path" ]]; then
        "$repo_dir/scripts/prepare-mutter-source.sh" >/dev/null
    fi
fi

if [[ ! -f "$srpm_path" ]]; then
    printf 'Mutter source RPM does not exist: %s\n' "$srpm_path" >&2
    exit 1
fi
srpm_path=$(realpath -- "$srpm_path")
rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.src.rpm\n' "$srpm_path" \
    >"$work_dir/upstream-source-rpm.txt"

rm -rf "$top_dir" "$input_dir"
mkdir -p "$top_dir/BUILD" "$top_dir/BUILDROOT" "$top_dir/RPMS" \
    "$top_dir/SOURCES" "$top_dir/SPECS" "$top_dir/SRPMS" "$input_dir"

(
    cd "$input_dir"
    rpm2cpio "$srpm_path" | cpio -idm
)

spec_path=$(find "$input_dir" -maxdepth 1 -type f -name '*.spec' -print -quit)
if [[ -z "$spec_path" ]]; then
    printf 'No spec file found in %s\n' "$srpm_path" >&2
    exit 1
fi

find "$input_dir" -maxdepth 1 -type f ! -name '*.spec' \
    -exec cp -t "$top_dir/SOURCES" -- {} +
cp -- "$spec_path" "$top_dir/SPECS/mutter.spec"

patch_number=9000
for patch_path in "$repo_dir"/mutter-patches/[0-9][0-9][0-9][0-9]-*.patch; do
    patch_number=$((patch_number + 1))
    patch_name=$(basename -- "$patch_path")
    cp -- "$patch_path" "$top_dir/SOURCES/$patch_name"
    sed -i \
        "0,/^BuildRequires:/s//Patch${patch_number}:     ${patch_name}\\n&/" \
        "$top_dir/SPECS/mutter.spec"
done

sed -i -E "s/^Release:[[:space:]].*/Release:       %autorelease -e ${release_tag}/" \
    "$top_dir/SPECS/mutter.spec"

if ! rg -q '^Patch9001:' "$top_dir/SPECS/mutter.spec" ||
   ! rg -q "^Release:.*${release_tag}" "$top_dir/SPECS/mutter.spec"; then
    printf 'Failed to inject the local patch stack into the Mutter spec.\n' >&2
    exit 1
fi

printf '%s\n' "$top_dir/SPECS/mutter.spec"
