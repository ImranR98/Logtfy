#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

if [[ "$LOG_LINE" =~ ^Port ]]; then
    echo "Port Checker on $(hostname -f)


$LOG_LINE"
fi
