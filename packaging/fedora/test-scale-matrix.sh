#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

for scale in 2.0 2.5 3.0; do
    artifact_dir="$repo_dir/tests/artifacts/scale-$scale"
    GWA_TEST_SCALE="$scale" GWA_TEST_ARTIFACT_DIR="$artifact_dir" \
        "$repo_dir/packaging/fedora/test-rpms.sh"
done

printf 'Optimized RPM passed the 200%%, 250%% and 300%% scale matrix.\n'
