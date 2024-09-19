#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

NUM_SECONDS_RECALL="86400"
if [ -n "$EXTRA_DATA" ]; then
    NUM_SECONDS_RECALL="$EXTRA_DATA"
fi

TEMP_LOGS_FILE=/tmp/logtfy/traefik_accesslogs

if echo "$LOG_LINE" | grep -q -E '^{.*\}$'; then
    LOG_DATA="$(echo "$LOG_LINE" | jq -r '.time + "~" +.ClientHost + "~" + .RequestAddr')"
    if [ ! -f "$TEMP_LOGS_FILE" ]; then
        touch "$TEMP_LOGS_FILE"
    else
        temp_file="$(mktemp)"
        current_time=$(date -u +%s)
        cutoff_time=$(($current_time - "$NUM_SECONDS_RECALL")) # Keep only the last 24H in this file
        while IFS= read -r line; do
            utc_string=$(echo "$line" | awk -F '~' '{print $1}')
            line_time=$(date -u -d "$utc_string" +%s)
            if [ "$line_time" -ge "$cutoff_time" ]; then
                echo "$line" >>"$temp_file"
            fi
        done <"$TEMP_LOGS_FILE"
        mv "$temp_file" "$TEMP_LOGS_FILE"
    fi

    TIME=$(echo "$LOG_DATA" | cut -d'~' -f1)
    IP=$(echo "$LOG_DATA" | cut -d'~' -f2)
    URL=$(echo "$LOG_DATA" | cut -d'~' -f3)

    if [ -z "$(grep -E "^[^~]+~$IP$" "$TEMP_LOGS_FILE")" ]; then
        echo "$TIME~$IP" >>"$TEMP_LOGS_FILE"
        echo "Traefik on $(hostname -f): New Client IP (within $(("$NUM_SECONDS_RECALL" / 3600))H)


$IP requested $URL at $TIME"
    fi
fi
