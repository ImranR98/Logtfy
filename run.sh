#!/bin/bash -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

trap "if [ -f "$HERE"/onExit.sh ]; then bash "$HERE"/onExit.sh; else bash "$HERE"/onExit.default.sh; fi; trap - SIGTERM && kill -- -\$\$" EXIT

for MODULE_REL_PATH in ./modules/*; do
    MODULE_ID="$(basename "$MODULE_REL_PATH")"
    IS_ENABLED="$(node "$HERE"/configParser.js isModuleEnabled "$MODULE_ID")"
    if [ "$IS_ENABLED" == true ]; then
        LOGGER_EXTRA_DATA="$(node "$HERE"/configParser.js getLoggerArgForModule "$MODULE_ID")"
        PARSER_EXTRA_DATA="$(node "$HERE"/configParser.js getParserArgForModule "$MODULE_ID")"
        bash "$HERE"/runModule.sh "$MODULE_ID" "$LOGGER_EXTRA_DATA" "$PARSER_EXTRA_DATA" &
    fi
done

wait -n
