#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

if [ -z "$EXTRA_DATA" ]; then
    exit 0
fi

REGEX="$(echo "$EXTRA_DATA" | jq -r '.regex // empty')"
TITLE="$(echo "$EXTRA_DATA" | jq -r '.title // empty')"
MESSAGE="$(echo "$EXTRA_DATA" | jq -r '.message // empty')"

if echo "$LOG_LINE" | grep -qE "$REGEX"; then
    echo "${TITLE:-Logtfy Alert}"
    echo ""
    echo ""
    if [ -n "$MESSAGE" ]; then
        echo "$MESSAGE"
    fi
    echo "$LOG_LINE"
fi
