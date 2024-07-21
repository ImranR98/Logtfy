#!/bin/bash -e

LOG_LINE="$1"
EXTRA_DATA="$2"

if echo "$LOG_LINE" | grep -q "sshd.*session opened"; then
    echo "SSH login to $(hostname -f)


$(echo "$LOG_LINE" | awk "{print \$11}") at $(date)"
fi
