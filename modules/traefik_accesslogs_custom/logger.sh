#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

ACCESS_LOGS_FILE="${1:-/traefik_logs/access.log}"
tail -f "$ACCESS_LOGS_FILE"
