#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

IFS=', ' read -r -a EXCLUDED_DEVICE_IDS <<<"$EXTRA_DATA"

NOTIF=""
DEVICE_ID=""

if echo "$LOG_LINE" | grep -q -E 'INFO: Device [^ ]+ client is'; then
    NOTIF_DATE="$(echo "$LOG_LINE" | awk '{print $2}')"
    NOTIF_TIME="$(echo "$LOG_LINE" | awk '{print $3}')"
    DEVICE_ID="$(echo "$LOG_LINE" | awk '{print $6}')"
    DEVICE_NAME="$(echo "$LOG_LINE" | awk -F '"' '{print $4}')"
    NOTIF="Syncthing on $(hostname -f): Device Connected


$DEVICE_ID ($DEVICE_NAME) at $NOTIF_TIME on $NOTIF_DATE"
elif echo "$LOG_LINE" | grep -q -E 'INFO: Lost primary connection to'; then
    NOTIF_DATE="$(echo "$LOG_LINE" | awk '{print $2}')"
    NOTIF_TIME="$(echo "$LOG_LINE" | awk '{print $3}')"
    DEVICE_ID="$(echo "$LOG_LINE" | awk '{print $9}')"
    NOTIF="Syncthing on $(hostname -f): Device Disconnected


$DEVICE_ID at $NOTIF_TIME on $NOTIF_DATE"
fi

if [ -n "$NOTIF" ]; then
    IS_EXCLUDED=false
    for i in "${EXCLUDED_DEVICE_IDS[@]}"; do
        if [ "$i" == "$DEVICE_ID" ]; then
            IS_EXCLUDED=true
        fi
    done
    if [ "$IS_EXCLUDED" = false ]; then
        echo "$NOTIF"
    fi
fi
