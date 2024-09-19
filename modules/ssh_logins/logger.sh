#!/bin/bash
set -e

EXTRA_DATA="$1"

JOURNALCTL_USER='sshd'
if [ -n "$EXTRA_DATA" ]; then
    JOURNALCTL_USER="$EXTRA_DATA"
fi

/usr/bin/journalctl -D /var/log/journal -S now -fu "$JOURNALCTL_USER"