#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work_dir="$repo_dir/_build/fedora"
runtime_dir="$work_dir/rpm-runtime"
extract_dir="$runtime_dir/extracted"
library_dir="$runtime_dir/core-library"
main_rpm=$(find "$work_dir/rpmbuild/RPMS" -type f \
    -name 'mutter-[0-9]*.x86_64.rpm' -print -quit)

"$repo_dir/packaging/fedora/verify-rpms.sh"
if [[ -z "$main_rpm" ]]; then
    printf 'The locally built main Mutter RPM was not found.\n' >&2
    exit 1
fi

rm -rf "$runtime_dir"
mkdir -p "$extract_dir" "$library_dir"
(
    cd "$extract_dir"
    rpm2cpio "$main_rpm" | cpio -idm
)
find "$extract_dir/usr/lib64" -maxdepth 1 \
    \( -type f -o -type l \) -name 'libmutter-18.so.0*' \
    -exec cp -a -t "$library_dir" -- {} +

if [[ ! -f "$library_dir/libmutter-18.so.0.0.0" ]]; then
    printf 'The main RPM does not contain the expected libmutter ABI.\n' >&2
    exit 1
fi

TEST_MUTTER_LIBRARY_DIR="$library_dir" \
    "$repo_dir/tests/run-mutter-nested.sh"

printf 'Optimized RPM libmutter passed the nested rendering regression.\n'
