#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

if [[ "$LOG_LINE" =~ ^Port\ Checker ]]; then
    echo "$LOG_LINE"
fi
