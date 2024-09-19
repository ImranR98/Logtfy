#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

NUM_SECONDS_RECALL="86400"
if [ -n "$EXTRA_DATA" ]; then
    NUM_SECONDS_RECALL="$EXTRA_DATA"
fi

TEMP_LOGS_FILE=/tmp/logtfy/traefik_geoblock_allowed_requests

if echo "$LOG_LINE" | grep -q -E 'GeoBlock:.+request allowed'; then
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

    TIME="$(date -u -d "$(echo "$LOG_LINE" | awk '{print $3, $4}')" +"%Y-%m-%dT%H:%M:%SZ")"
    IP=$(echo "$LOG_LINE" | awk '{print $8}')
    COUNTRY=$(echo "$LOG_LINE" | awk '{print $11}')

    if [ -z "$(grep -F "~$IP" "$TEMP_LOGS_FILE")" ]; then
        echo "$TIME~$IP" >>"$TEMP_LOGS_FILE"
        echo "Traefik on $(hostname -f): New Allowed Client IP (within $(("$NUM_SECONDS_RECALL" / 3600))H)


$IP from $COUNTRY at $TIME"
    fi
fi
