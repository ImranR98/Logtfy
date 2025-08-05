#!/bin/bash
set -e

LOG_LINE="$1"
LINE_MATCH_PATTERN="$2"

if [ -z "$LINE_MATCH_PATTERN" ]; then
    echo "NO PATTERN PROVIDED!"
    exit 1
fi

if echo "$LOG_LINE" | grep -q "$LINE_MATCH_PATTERN"; then
    NOTIF_IP="$(echo "$LOG_LINE" | awk '{print $1}')"
    NOTIF_DATE_TIME="$(echo "$LOG_LINE" | awk '{print $4}' | tail -c +2)"
    NOTIF_DATA="$(echo "$LOG_LINE" | cut -d ' ' -f 6-)"
    echo "Traefik Access Alert on $(hostname -f)


From ($NOTIF_IP) at $NOTIF_DATE_TIME: $NOTIF_DATA"
fi