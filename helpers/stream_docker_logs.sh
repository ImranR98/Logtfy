#!/bin/bash
set -e

CONTAINER_NAME="$1"

/usr/bin/docker logs -f --since 0m "$CONTAINER_NAME" 2>/dev/null