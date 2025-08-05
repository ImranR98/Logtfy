#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

EXTRA_DATA="$1"

ACCESS_LOGS_FILE='/traefik_logs/access.log'
if [ -n "$EXTRA_DATA" ]; then
    ACCESS_LOGS_FILE="$EXTRA_DATA"
fi

tail -f "$ACCESS_LOGS_FILE"