#!/bin/bash

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

MODULE_ID="$1"
LOGGER_EXTRA_DATA="$2"
PARSER_EXTRA_DATA="$3"
NTFY_CONFIGS="$4"
TAIL_TO_FILE="$5"
DEFAULT_PRIORITY="$6"
DEFAULT_TAGS="$7"

bash "$HERE"/modules/"$MODULE_ID"/logger.sh "$LOGGER_EXTRA_DATA" | while read -r log; do
    echo "$log" >> "$TAIL_TO_FILE"
    TAIL="$(tail "$TAIL_TO_FILE")"
    echo "$TAIL" > "$TAIL_TO_FILE"
    PARSER_OUTPUT="$(bash "$HERE"/modules/"$MODULE_ID"/parser.sh "$log" "$PARSER_EXTRA_DATA")"
    if [ -n "$PARSER_OUTPUT" ]; then
        node "$HERE"/notify.js "$MODULE_ID" "$PARSER_OUTPUT" "$NTFY_CONFIGS" "$DEFAULT_PRIORITY" "$DEFAULT_TAGS" || : # Don't crash everything if a notif fails to send
    fi
done
