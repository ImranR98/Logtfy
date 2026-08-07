#!/bin/bash

CONTAINER_NAME="$1"
STDERR_MODE="${2:-}"

case "$STDERR_MODE" in
    stderr2stdout) /usr/bin/docker logs -f --since 0m "$CONTAINER_NAME" 2>&1 ;;
    printstderr)   /usr/bin/docker logs -f --since 0m "$CONTAINER_NAME" ;;
    *)             /usr/bin/docker logs -f --since 0m "$CONTAINER_NAME" 2>/dev/null ;;
esac
