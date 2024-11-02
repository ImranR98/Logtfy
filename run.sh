#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ "$1" = 'k8s' ]; then # For easy access through the Docker image without cloning the repo
    cat "$HERE"/k8s/prep.sh
    echo ""
    echo "# Put the above script into a file and run it on your K8s control plane. Make the resulting files accessible to Logtfy."
    exit
fi
if [ "$1" = 'role' ]; then # For easy access through the Docker image without cloning the repo
    cat "$HERE"/k8s/role.yaml
    echo ""
    echo "# Put the above yaml into a file and run it on your K8s control plane."
    exit
fi

trap "if [ -f "$HERE"/onExit.sh ]; then bash "$HERE"/onExit.sh; else bash "$HERE"/onExit.default.sh; fi; trap - SIGTERM && kill -- -\$\$ 2>/dev/null" EXIT

mkdir -p /tmp/logtfy # Semi-persistent storage used by some modules
for MODULE_REL_PATH in "$HERE"/modules/*; do
    MODULE_ID="$(basename "$MODULE_REL_PATH")"
    IS_ENABLED="$(node "$HERE"/configParser.js isModuleEnabled "$MODULE_ID")"
    if [ "$IS_ENABLED" == true ]; then
        LOGGER_EXTRA_DATA="$(node "$HERE"/configParser.js getLoggerArgForModule "$MODULE_ID")"
        PARSER_EXTRA_DATA="$(node "$HERE"/configParser.js getParserArgForModule "$MODULE_ID")"
        NTFY_CONFIGS="$(node "$HERE"/configParser.js getNtfyConfigsForModule "$MODULE_ID")"
        MODULE_STRING="$(node "$HERE"/configParser.js getModuleSummaryString "$MODULE_ID" "$NTFY_CONFIGS")"
        DEFAULT_PRIORITY="$(node "$HERE"/configParser.js getDefaultPriorityForModule "$MODULE_ID")"
        DEFAULT_TAGS="$(node "$HERE"/configParser.js getDefaultTagsForModule "$MODULE_ID")"
        MAX_FAILS="$(node "$HERE"/configParser.js getModuleAllowedFailCount)"
        (
            EXITED_CLEANLY=true
            FAIL_COUNT=0
            MAX_FAILS=3
            while [ $MAX_FAILS -eq 0 ] || [ $FAIL_COUNT -lt $MAX_FAILS ]; do
                TEMP_LOG_FILE="$(mktemp)"
                echo "Running module: $MODULE_STRING..."
                set -o pipefail
                bash "$HERE"/runModule.sh "$MODULE_ID" "$LOGGER_EXTRA_DATA" "$PARSER_EXTRA_DATA" "$NTFY_CONFIGS" "$TEMP_LOG_FILE" "$DEFAULT_PRIORITY" "$DEFAULT_TAGS" || EXITED_CLEANLY=false
                set +o pipefail
                FAIL_COUNT=$((FAIL_COUNT + 1))
                echo "
$(printf "%0.s=" $(seq 1 "$(tput cols)"))
Module '$MODULE_ID' failed $FAIL_COUNT/$MAX_FAILS times. Log tail:
$(printf "%0.s-" $(seq 1 "$(tput cols)"))
$(cat "$TEMP_LOG_FILE")
$(printf "%0.s=" $(seq 1 "$(tput cols)"))
"
                rm "$TEMP_LOG_FILE"
            done
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
