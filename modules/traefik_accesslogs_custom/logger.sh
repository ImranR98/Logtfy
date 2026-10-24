#!/bin/bash
set -e

ACCESS_LOGS_FILE="${1:-/traefik_logs/access.log}"
tail -f "$ACCESS_LOGS_FILE"
