#!/bin/bash
# Shared assertions and runner for the Logtfy test suite.
# Sourced by tests/run-tests.sh; test files must not execute anything directly.

if [ -z "${ROOT:-}" ]; then
    echo "ROOT must be set before sourcing tests/lib.sh" >&2
    exit 1
fi

TESTS_RUN=0
TESTS_FAILED=0

fail() {
    echo "assertion failed: $*" >&2
    return 1
}

assert_eq() {
    local actual="$1"
    local expected="$2"
    if [ "$actual" != "$expected" ]; then
        echo "expected: [$expected]" >&2
        echo "actual:   [$actual]" >&2
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    case "$haystack" in
        *"$needle"*) return 0 ;;
    esac
    echo "expected to find: [$needle]" >&2
    echo "in:               [$haystack]" >&2
    return 1
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    case "$haystack" in
        *"$needle"*)
            echo "expected not to find: [$needle]" >&2
            echo "in:                   [$haystack]" >&2
            return 1
            ;;
    esac
    return 0
}

assert_empty() {
    local actual="$1"
    if [ -n "$actual" ]; then
        echo "expected empty output, got: [$actual]" >&2
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local needle="$2"
    if [ ! -f "$file" ]; then
        echo "expected file to exist: $file" >&2
        return 1
    fi
    assert_contains "$(cat "$file")" "$needle"
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "required command is missing: $1" >&2
        return 1
    fi
}

# Copy the repository (minus .git) into a temp directory so tests can add
# fixture modules or replace notify.js without touching the checkout.
copy_repo() {
    local dest="$1"
    tar -C "$ROOT" --exclude=.git -cf - . | tar -C "$dest" -xf -
}

# Write a notify.js recorder so tests never talk to a real ntfy server.
install_notify_recorder() {
    local dest="$1"
    cat > "$dest/notify.js" <<'EOF'
const fs = require('fs')
const args = process.argv.slice(2)
if (!process.env.NOTIFY_LOG) {
    console.error('NOTIFY_LOG is not set')
    process.exit(1)
}
fs.appendFileSync(process.env.NOTIFY_LOG, JSON.stringify(args) + '\n')
EOF
}

run_test() {
    local name="$1"
    shift
    local output
    local rc

    TESTS_RUN=$((TESTS_RUN + 1))
    output="$(
        set -e
        "$@" 2>&1
    )"
    rc=$?

    if [ "$rc" -eq 0 ]; then
        printf 'PASS %s\n' "$name"
    else
        printf 'FAIL %s\n' "$name"
        printf '%s\n' "$output" | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}
