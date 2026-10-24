#!/bin/bash

CONTAINER_NAME="$1"
STDERR_MODE="${2:-}"
DOCKER_BIN="${DOCKER_BIN:-/usr/bin/docker}"

case "$STDERR_MODE" in
    stderr2stdout) "$DOCKER_BIN" logs -f --since 0m "$CONTAINER_NAME" 2>&1 ;;
    printstderr)   "$DOCKER_BIN" logs -f --since 0m "$CONTAINER_NAME" ;;
    *)             "$DOCKER_BIN" logs -f --since 0m "$CONTAINER_NAME" 2>/dev/null ;;
esac
