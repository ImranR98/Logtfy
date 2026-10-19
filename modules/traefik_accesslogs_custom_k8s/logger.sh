#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

read NAMESPACE SERVICE_NAME <<< "$1"
FILTER="$2"

if [ -z "$SERVICE_NAME" ]; then
    SERVICE_NAME=traefik
fi

# Filter in the streaming pipeline rather than forking a parser for every
# Traefik access log line. The parser still applies the same regex.
source "$HERE"/../../k8s/stream_service_logs.sh "$SERVICE_NAME $NAMESPACE" |
    grep -E --line-buffered "$FILTER" || true
