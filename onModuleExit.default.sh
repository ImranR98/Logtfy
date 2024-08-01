#!/bin/bash -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

MODULE_ID="$1"
if [ "$2" = true ]; then
    EXITED_CLEANLY_STRING=" with a non-0 exit code"
fi

NTFY_CONFIGS="$(node "$HERE"/configParser.js getNtfyConfigsForModule logtfy)"
PARSER_OUTPUT="Logtfy on $(hostname -f): '$MODULE_ID' Exited
3

The '$MODULE_ID' Logtfy module has exited$EXITED_CLEANLY_STRING. This is unexpected - you may need to check for errors."

node "$HERE"/notify.js "logtfy" "$PARSER_OUTPUT" "$NTFY_CONFIGS"
