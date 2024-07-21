#!/bin/bash -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

MODULE_ID="$1"
LOGGER_EXTRA_DATA="$2"
PARSER_EXTRA_DATA="$3"

NTFY_CONFIGS="$(node "$HERE"/configParser.js getNtfyConfigsForModule "$MODULE_ID")"
MODULE_STRING="$(node "$HERE"/configParser.js getModuleSummaryString "$MODULE_ID" "$NTFY_CONFIGS")"

echo "Running module: $MODULE_STRING..."

bash "$HERE"/modules/"$MODULE_ID"/logger.sh "$LOGGER_EXTRA_DATA" | while read -r log; do
    PARSER_OUTPUT="$(bash "$HERE"/modules/"$MODULE_ID"/parser.sh "$log" "$PARSER_EXTRA_DATA")"
    if [ -n "$PARSER_OUTPUT" ]; then
        node "$HERE"/notify.js "$MODULE_ID" "$PARSER_OUTPUT" "$NTFY_CONFIGS" || : # Don't crash everything if a notif fails to send
    fi
done
