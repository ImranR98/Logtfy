#!/bin/bash -e

EXTRA_DATA="$1"

CONTAINER_NAME='traefik'
if [ -n "$EXTRA_DATA" ]; then
    CONTAINER_NAME="$EXTRA_DATA"
fi

/usr/bin/docker logs -f --since 0m "$CONTAINER_NAME" 2>/dev/null