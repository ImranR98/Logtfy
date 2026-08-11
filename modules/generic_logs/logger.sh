#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

EXTRA_DATA="$1"
read FIRST REST <<< "$EXTRA_DATA"

if [ "$FIRST" = 'k8s' ]; then
    read SERVICE_NAME NAMESPACE <<< "$REST"
    : "${SERVICE_NAME:?Service name not specified in loggerArg!}"
    source "$HERE"/../../k8s/stream_service_logs.sh "$SERVICE_NAME $NAMESPACE"
else
    CONTAINER_NAME="$FIRST"
    read STDERR_MODE <<< "$REST"
    : "${CONTAINER_NAME:?Container name not specified in loggerArg!}"
    source "$HERE"/../../helpers/stream_docker_logs.sh "$CONTAINER_NAME" "$STDERR_MODE"
fi
