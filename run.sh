#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ "$1" = 'k8s' ]; then
    cat "$HERE"/k8s/prep.sh
    echo ""
    echo "# Put the above script into a file and run it on your K8s control plane. Make the resulting files accessible to Logtfy."
    exit
fi
if [ "$1" = 'role' ]; then
    cat "$HERE"/k8s/role.yaml
    echo ""
    echo "# Put the above yaml into a file and run it on your K8s control plane."
    exit
fi

MODULE_PIDS=()

shutdown() {
    if [ -f "$HERE"/onExit.sh ]; then
        bash "$HERE"/onExit.sh
    fi
    for pid in "${MODULE_PIDS[@]}"; do
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
    done
    exit 0
}
trap shutdown SIGTERM SIGINT EXIT

mkdir -p /tmp/logtfy

NOTIFY_INITIAL="$(node "$HERE"/configParser.js getCrashNotificationInitialBackoffSeconds)"
NOTIFY_MAX="$(node "$HERE"/configParser.js getCrashNotificationMaxBackoffSeconds)"

for MODULE_REL_PATH in "$HERE"/modules/*; do
    MODULE_ID="$(basename "$MODULE_REL_PATH")"
    IS_ENABLED="$(node "$HERE"/configParser.js isModuleEnabled "$MODULE_ID")"
    if [ "$IS_ENABLED" = true ]; then
        LOGGER_EXTRA_DATA="$(node "$HERE"/configParser.js getLoggerArgForModule "$MODULE_ID")"
        PARSER_EXTRA_DATA="$(node "$HERE"/configParser.js getParserArgForModule "$MODULE_ID")"
        NTFY_CONFIGS="$(node "$HERE"/configParser.js getNtfyConfigsForModule "$MODULE_ID")"
        MODULE_STRING="$(node "$HERE"/configParser.js getModuleSummaryString "$MODULE_ID" "$NTFY_CONFIGS")"
        DEFAULT_PRIORITY="$(node "$HERE"/configParser.js getDefaultPriorityForModule "$MODULE_ID")"
        DEFAULT_TAGS="$(node "$HERE"/configParser.js getDefaultTagsForModule "$MODULE_ID")"
        (
            set +e

            cleanup() {
                node "$HERE"/notify.js "$MODULE_ID" "Logtfy on $(hostname -f): '$MODULE_ID' Container Kill
5
$DEFAULT_TAGS
The '$MODULE_ID' module stopped because the container was killed." "$NTFY_CONFIGS" || true
            }
            trap cleanup EXIT

            node "$HERE"/notify.js "$MODULE_ID" "Logtfy on $(hostname -f): '$MODULE_ID' Module Started
3
$DEFAULT_TAGS
The '$MODULE_ID' module has started." "$NTFY_CONFIGS" || true

            RESTART_DELAY=5
            STABLE_THRESHOLD=60
            notify_interval=$NOTIFY_INITIAL
            last_notify=0
            first_run=true

            while true; do
                TEMP_LOG_FILE="$(mktemp)"
                ITER_START="$(date +%s)"
                echo "Running module: $MODULE_STRING..."

                if [ "$first_run" = true ] || [ "$last_notify" -ne 0 ]; then
                    (
                        sleep "$STABLE_THRESHOLD"
                        node "$HERE"/notify.js "$MODULE_ID" "Logtfy on $(hostname -f): '$MODULE_ID' Stable
3
$DEFAULT_TAGS
The '$MODULE_ID' module is stable after ${STABLE_THRESHOLD}s of uptime." "$NTFY_CONFIGS" || true
                    ) &
                    WATCHDOG_PID=$!
                else
                    WATCHDOG_PID=0
                fi

                bash "$HERE"/runModule.sh "$MODULE_ID" "$LOGGER_EXTRA_DATA" "$PARSER_EXTRA_DATA" "$NTFY_CONFIGS" "$TEMP_LOG_FILE" "$DEFAULT_PRIORITY" "$DEFAULT_TAGS" || true
                RUNTIME=$(($(date +%s) - ITER_START))

                if [ "$WATCHDOG_PID" -ne 0 ]; then
                    kill "$WATCHDOG_PID" 2>/dev/null
                    wait "$WATCHDOG_PID" 2>/dev/null
                fi

                printf '=%.0s' $(seq 1 60); echo
                echo "Module '$MODULE_ID' exited after ${RUNTIME}s. Log tail:"
                printf -- '-%.0s' $(seq 1 60); echo
                cat "$TEMP_LOG_FILE"
                printf '=%.0s' $(seq 1 60); echo

                if [ "$RUNTIME" -ge "$STABLE_THRESHOLD" ]; then
                    notify_interval=$NOTIFY_INITIAL
                    last_notify=0
                    first_run=false
                else
                    NOW="$(date +%s)"
                    if [ "$last_notify" -eq 0 ] || [ $((NOW - last_notify)) -ge "$notify_interval" ]; then
                        LOG_TAIL="$(cat "$TEMP_LOG_FILE")"
                        node "$HERE"/notify.js "$MODULE_ID" "Logtfy on $(hostname -f): '$MODULE_ID' Crashed
5
$DEFAULT_TAGS
The '$MODULE_ID' module crashed after ${RUNTIME}s. Log tail:
$LOG_TAIL" "$NTFY_CONFIGS" || true
                        if [ "$last_notify" -ne 0 ]; then
                            notify_interval=$((notify_interval * 2))
                            if [ "$notify_interval" -gt "$NOTIFY_MAX" ]; then
                                notify_interval=$NOTIFY_MAX
                            fi
                        fi
                        last_notify=$NOW
                    else
                        SECONDS_SINCE_LAST=$(($(date +%s) - last_notify))
                        SECONDS_UNTIL_NEXT=$((notify_interval - SECONDS_SINCE_LAST))
                        echo "Crash notification suppressed by backoff (next notification in ${SECONDS_UNTIL_NEXT}s, current interval ${notify_interval}s)"
                    fi
                fi
                rm -f "$TEMP_LOG_FILE"
                echo "Restarting module '$MODULE_ID' in ${RESTART_DELAY}s..."
                sleep "$RESTART_DELAY"
            done
        ) &
        MODULE_PIDS+=("$!")
    fi
done

wait
