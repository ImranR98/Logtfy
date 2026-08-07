#!/bin/bash

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

MODULE_ID="$1"
LOGGER_EXTRA_DATA="$2"
PARSER_EXTRA_DATA="$3"
NTFY_CONFIGS="$4"
TAIL_TO_FILE="$5"
DEFAULT_PRIORITY="$6"
DEFAULT_TAGS="$7"

LOGGER_PIPE="$(mktemp -u)"
mkfifo "$LOGGER_PIPE"
trap "rm -f '$LOGGER_PIPE'" EXIT

bash "$HERE"/modules/"$MODULE_ID"/logger.sh "$LOGGER_EXTRA_DATA" > "$LOGGER_PIPE" &
LOGGER_PID=$!

while read -r log; do
    echo "$log" >> "$TAIL_TO_FILE"
    tail "$TAIL_TO_FILE" > "$TAIL_TO_FILE"
    PARSER_OUTPUT="$(bash "$HERE"/modules/"$MODULE_ID"/parser.sh "$log" "$PARSER_EXTRA_DATA" || true)"
    if [ -n "$PARSER_OUTPUT" ]; then
        node "$HERE"/notify.js "$MODULE_ID" "$PARSER_OUTPUT" "$NTFY_CONFIGS" "$DEFAULT_PRIORITY" "$DEFAULT_TAGS" || :
    fi
done < "$LOGGER_PIPE"

wait $LOGGER_PID
LOGGER_EXIT=$?
rm -f "$LOGGER_PIPE"
trap - EXIT
exit $LOGGER_EXIT
