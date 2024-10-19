#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

read NAMESPACE SERVICE_NAME <<< "$1"

if [ -z "$SERVICE_NAME" ]; then
    SERVICE_NAME=syncthing
fi

source "$HERE"/../../k8s/stream_service_logs.sh "$SERVICE_NAME $NAMESPACE"