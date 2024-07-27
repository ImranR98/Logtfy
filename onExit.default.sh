#!/bin/bash -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

NTFY_CONFIGS="$(node "$HERE"/configParser.js getNtfyConfigsForModule logtfy)"
PARSER_OUTPUT="Logtfy on $(hostname -f): Exited
5

Logtfy has exited. This is unexpected - you may need to check for errors."

node "$HERE"/notify.js "logtfy" "$PARSER_OUTPUT" "$NTFY_CONFIGS"