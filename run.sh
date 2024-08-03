#!/bin/bash -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

trap "if [ -f "$HERE"/onExit.sh ]; then bash "$HERE"/onExit.sh; else bash "$HERE"/onExit.default.sh; fi; trap - SIGTERM && kill -- -\$\$" EXIT

mkdir -p /tmp/logtfy # Semi-persistent storage used by some modules
for MODULE_REL_PATH in "$HERE"/modules/*; do
    MODULE_ID="$(basename "$MODULE_REL_PATH")"
    IS_ENABLED="$(node "$HERE"/configParser.js isModuleEnabled "$MODULE_ID")"
    if [ "$IS_ENABLED" == true ]; then
        LOGGER_EXTRA_DATA="$(node "$HERE"/configParser.js getLoggerArgForModule "$MODULE_ID")"
        PARSER_EXTRA_DATA="$(node "$HERE"/configParser.js getParserArgForModule "$MODULE_ID")"
        (
            EXITED_CLEANLY=true
            bash "$HERE"/runModule.sh "$MODULE_ID" "$LOGGER_EXTRA_DATA" "$PARSER_EXTRA_DATA" || EXITED_CLEANLY=false
            if [ -f "$HERE"/onModuleExit.sh ]; then
                bash "$HERE"/onModuleExit.sh "$MODULE_ID" "$EXITED_CLEANLY"
            else
                bash "$HERE"/onModuleExit.default.sh "$MODULE_ID" "$EXITED_CLEANLY"
            fi
        ) &
    fi
done

if [ "$(node "$HERE"/configParser.js shouldCatchModuleCrashes)" = true ]; then
    wait
else
    wait -n
fi