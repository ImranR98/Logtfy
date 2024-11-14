#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

EXTRA_DATA="$1"

CONTAINER_NAME='watchtower'
if [ -n "$EXTRA_DATA" ]; then
    CONTAINER_NAME="$EXTRA_DATA"
fi

source "$HERE"/../../helpers/stream_docker_logs.sh "$CONTAINER_NAME"