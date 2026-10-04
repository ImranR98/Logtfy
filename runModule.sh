#!/bin/bash
set -e

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
LOGGER_ERR_FILE="$(mktemp)"

bash "$HERE"/modules/"$MODULE_ID"/logger.sh "$LOGGER_EXTRA_DATA" > "$LOGGER_PIPE" 2> "$LOGGER_ERR_FILE" &
LOGGER_PID=$!

while read -r log; do
    echo "$log" >> "$TAIL_TO_FILE"
    TAIL_CONTENT="$(tail "$TAIL_TO_FILE")"
    echo "$TAIL_CONTENT" > "$TAIL_TO_FILE"
    PARSER_OUTPUT="$(bash "$HERE"/modules/"$MODULE_ID"/parser.sh "$log" "$PARSER_EXTRA_DATA" || true)"
    if [ -n "$PARSER_OUTPUT" ]; then
        node "$HERE"/notify.js "$MODULE_ID" "$PARSER_OUTPUT" "$NTFY_CONFIGS" "$DEFAULT_PRIORITY" "$DEFAULT_TAGS" || true
    fi
done < "$LOGGER_PIPE"

LOGGER_EXIT=0
wait "$LOGGER_PID" || LOGGER_EXIT=$?

if [ -s "$LOGGER_ERR_FILE" ]; then
    cat "$LOGGER_ERR_FILE" >&2
    { cat "$TAIL_TO_FILE" 2>/dev/null || true; tail -n 10 "$LOGGER_ERR_FILE"; } | tail -n 10 > "$TAIL_TO_FILE.tmp" && mv "$TAIL_TO_FILE.tmp" "$TAIL_TO_FILE"
fi

rm -f "$LOGGER_ERR_FILE" "$LOGGER_PIPE"
exit "$LOGGER_EXIT"
