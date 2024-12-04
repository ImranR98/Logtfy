#!/bin/bash
set -e

CONTAINER_NAME="$1"

if [ "$2" = 'stderr2stdout' ]; then
    /usr/bin/docker logs -f --since 0m "$CONTAINER_NAME" 2>&1
elif [ "$2" = 'printstderr' ]; then
    /usr/bin/docker logs -f --since 0m "$CONTAINER_NAME"
else
    /usr/bin/docker logs -f --since 0m "$CONTAINER_NAME" 2>/dev/null
fi
