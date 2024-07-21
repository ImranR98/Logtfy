#!/bin/bash -e

LOG_LINE="$1"
EXTRA_DATA="$2"

if echo "$LOG_LINE" | grep -qE "Successful .+authentication attempt"; then
    TIME="$(echo "$LOG_LINE" | awk -F\" "{print \$2}")"
    MESSAGE="$(echo "$LOG_LINE" | awk -F\" "{print \$4}")"
    IP="$(echo "$LOG_LINE" | awk -F= "{print \$NF}")"
    echo "Authelia on $(hostname -f): Successful Login


$MESSAGE from $IP at $TIME"
fi