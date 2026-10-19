#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

read NAMESPACE SERVICE_NAME <<< "$1"

if [ -z "$SERVICE_NAME" ]; then
    SERVICE_NAME=traefik
fi

# Only matching geoblock lines need the parser; keep the per-line fork out of
# the path for the rest of the Traefik log stream.
source "$HERE"/../../k8s/stream_service_logs.sh "$SERVICE_NAME $NAMESPACE" |
    grep -E --line-buffered 'GeoBlock:.+request allowed' || true