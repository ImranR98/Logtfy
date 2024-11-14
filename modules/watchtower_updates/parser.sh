#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

if echo "$LOG_LINE" | grep -qE "Found new"; then
    TIME="$(echo "$LOG_LINE" | awk -F\" "{print \$2}")"
    MESSAGE="$(echo "$LOG_LINE" | awk -F\" "{print \$4}")"
    IP="$(echo "$LOG_LINE" | awk -F= "{print \$NF}")"
    echo "Watchtower on $(hostname -f): Updating Image


$MESSAGE at $TIME"
fi