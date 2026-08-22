#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
rpm_dir="$repo_dir/_build/fedora/rpmbuild/RPMS"
expected_release=${GWA_RPM_RELEASE_TAG:-gwa1}
found_main=false

while IFS= read -r -d '' rpm_path; do
    rpm -K "$rpm_path"
    nevra=$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$rpm_path")
    if [[ "$nevra" != *".${expected_release}"* &&
          "$nevra" != *".${expected_release}."* ]]; then
        printf 'RPM lacks local release tag %s: %s\n' "$expected_release" "$nevra" >&2
        exit 1
    fi
    if [[ $(rpm -qp --qf '%{NAME}' "$rpm_path") == mutter ]]; then
        found_main=true
    fi
done < <(find "$rpm_dir" -type f -name '*.rpm' -print0 | sort -z)

if [[ "$found_main" != true ]]; then
    printf 'The main mutter RPM was not built under %s.\n' "$rpm_dir" >&2
    exit 1
fi

printf 'All locally built Mutter RPM signatures/digests and release tags are valid.\n'
