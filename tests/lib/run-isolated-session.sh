#!/usr/bin/env bash
set -euo pipefail

if (( $# == 0 )); then
    printf 'Usage: %s COMMAND [ARGUMENT ...]\n' "$0" >&2
    exit 2
fi

# Keep this path short: D-Bus and Wayland use Unix sockets whose pathname is
# limited to roughly 108 bytes on Linux. mktemp also makes concurrent test runs
# independent, and XDG_RUNTIME_DIR requires access by its owner only.
test_runtime_dir=$(mktemp -d /tmp/gwa-runtime.XXXXXX)
chmod 0700 "$test_runtime_dir"

session_pid=
# shellcheck disable=SC2329 # Invoked by the EXIT trap below.
cleanup() {
    status=$?
    trap - EXIT HUP INT TERM

    if [[ -n "$session_pid" ]]; then
        kill -TERM -- "-$session_pid" 2>/dev/null || true
        wait "$session_pid" 2>/dev/null || true
    fi

    # D-Bus-activated xdg-document-portal can take a moment to release its FUSE
    # mount after the bus disappears. Stop any remaining process-group members,
    # then allow that private mount to detach before reporting a cleanup error.
    for _ in {1..100}; do
        rm -rf -- "$test_runtime_dir" 2>/dev/null || true
        if [[ ! -e "$test_runtime_dir" ]]; then
            exit "$status"
        fi
        sleep 0.05
    done

    printf 'Failed to clean isolated XDG_RUNTIME_DIR: %s\n' \
        "$test_runtime_dir" >&2
    if (( status == 0 )); then
        status=1
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

export XDG_RUNTIME_DIR="$test_runtime_dir"

# A separate process group lets signal cleanup stop the complete nested session
# before removing its runtime directory, including D-Bus-activated services.
setsid --wait "$@" &
session_pid=$!

if wait "$session_pid"; then
    status=0
else
    status=$?
fi
exit "$status"
