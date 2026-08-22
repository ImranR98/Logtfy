#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

if echo "$LOG_LINE" | grep -qE "Found new"; then
    if echo "$LOG_LINE" | grep -qE '^time="'; then
        # logrus format (upstream + fork prior to zerolog migration)
        TIME="$(echo "$LOG_LINE" | awk -F\" "{print \$2}")"
        MESSAGE="$(echo "$LOG_LINE" | awk -F\" "{print \$4}")"
        if [ "$MESSAGE" = "Found new image" ]; then
            # For compatibility with fork: https://github.com/nicholas-fedor/watchtower
            MESSAGE="Found new image: $(echo "$LOG_LINE" | grep -Eo 'container=.*')"
        fi
    else
        # zerolog logfmt format (fork after logrus -> zerolog migration)
        TIME="$(echo "$LOG_LINE" | grep -oE '^time=[^ ]+' | cut -d= -f2-)"
        MESSAGE="Found new image: $(echo "$LOG_LINE" | grep -oE 'container=.*')"
    fi
    echo "Watchtower on $(hostname -f): Updating Image


$MESSAGE at $TIME"
fi