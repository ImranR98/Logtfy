#!/bin/bash
# Run the hermetic Logtfy test suite. No Docker socket, journal, Kubernetes
# cluster, or ntfy server is required; external calls are faked.
set -u

cd "$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$PWD"
export ROOT

# shellcheck source=tests/lib.sh
. tests/lib.sh

for cmd in node jq openssl timeout tar sed awk grep; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing required test tool: $cmd" >&2
        exit 1
    fi
done

for test_file in tests/test_*.sh; do
    # shellcheck source=/dev/null
    . "$test_file"
done

echo
echo "ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed"
if [ "$TESTS_FAILED" -ne 0 ]; then
    exit 1
fi
