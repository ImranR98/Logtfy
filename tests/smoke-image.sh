#!/bin/bash
# Build-time-independent smoke test for the production image. Runs the CLI
# helpers, checks the tools modules rely on, then starts the daemon with a
# fixture config and verifies it stays up and exits cleanly on SIGTERM.
#
#   tests/smoke-image.sh <image>
#
# Set CONTAINER_ENGINE=docker|podman to force an engine.
set -euo pipefail

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
    echo "usage: $0 <image>" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -n "${CONTAINER_ENGINE:-}" ]; then
    ENGINE="$CONTAINER_ENGINE"
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
else
    echo "no usable container engine (docker or podman)" >&2
    exit 1
fi

fail() {
    echo "SMOKE FAILED: $*" >&2
    exit 1
}

CONTAINER="logtfy-smoke-$$"
cleanup() {
    "$ENGINE" rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "engine: $ENGINE"
echo "image:  $IMAGE"

echo "== CLI helper: k8s =="
out="$("$ENGINE" run --rm "$IMAGE" k8s)"
case "$out" in
    *"kubectl apply -f -"*) ;;
    *) fail "run.sh k8s did not print the prep script" ;;
esac
case "$out" in
    *"logtfy-service-account-token"*) ;;
    *) fail "run.sh k8s output is missing the service-account token step" ;;
esac

echo "== CLI helper: role =="
out="$("$ENGINE" run --rm "$IMAGE" role)"
case "$out" in
    *"kind: ClusterRole"*) ;;
    *) fail "run.sh role did not print the RBAC role" ;;
esac

echo "== required tools =="
"$ENGINE" run --rm --entrypoint bash "$IMAGE" -c '
    set -e
    test -x /usr/bin/docker
    test -x /usr/bin/journalctl
    test -x "$(command -v nc)"
    docker --version
    journalctl --version | head -n 1
    jq --version
    node --version
    curl --version | head -n 1
'

echo "== daemon startup with fixture config =="
MOUNT_OPTS="ro"
if [ "$ENGINE" = "podman" ]; then
    MOUNT_OPTS="ro,Z"
fi

"$ENGINE" run -d --name "$CONTAINER" \
    -v "$ROOT/tests/fixtures/smoke-config.json:/logtfy/config.json:$MOUNT_OPTS" \
    "$IMAGE" >/dev/null

started=""
for _ in $(seq 1 40); do
    logs="$("$ENGINE" logs "$CONTAINER" 2>&1 || true)"
    case "$logs" in
        *"Running module: 'mock_module'"*) started="yes"; break ;;
    esac
    if ! "$ENGINE" inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
        echo "$logs" >&2
        fail "container exited before the module started"
    fi
    sleep 0.5
done
[ -n "$started" ] || { "$ENGINE" logs "$CONTAINER" >&2 || true; fail "module did not start within 20s"; }

sleep 2
if ! "$ENGINE" inspect -f '{{.State.Running}}' "$CONTAINER" | grep -q true; then
    "$ENGINE" logs "$CONTAINER" >&2 || true
    fail "daemon exited while the mock module should be running"
fi

logs="$("$ENGINE" logs "$CONTAINER" 2>&1 || true)"
case "$logs" in
    *"Crashed"*) fail "daemon reported a crash during the smoke run" ;;
    *"Restarting module"*) fail "daemon restarted the module during the smoke run" ;;
esac

echo "== graceful shutdown =="
"$ENGINE" stop -t 10 "$CONTAINER" >/dev/null
code="$("$ENGINE" inspect -f '{{.State.ExitCode}}' "$CONTAINER")"
[ "$code" = "0" ] || fail "expected exit code 0 after SIGTERM, got $code"

echo "image smoke passed"
