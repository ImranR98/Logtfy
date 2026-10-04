#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

if echo "$LOG_LINE" | grep -qE "Accepted (publickey|password|keyboard-interactive) for "; then
    SSH_USER="$(echo "$LOG_LINE" | sed -E 's/.*Accepted [a-z-]+ for ([^ ]+) from .*/\1/')"
    SSH_IP="$(echo "$LOG_LINE" | sed -E 's/.* from ([^ ]+) port [0-9]+ .*/\1/')"
    SSH_PORT="$(echo "$LOG_LINE" | sed -E 's/.* port ([0-9]+) .*/\1/')"
    echo "SSH login to $(hostname -f)"
    echo
    echo
    echo "$SSH_USER from $SSH_IP port $SSH_PORT at $(date)"
fi
