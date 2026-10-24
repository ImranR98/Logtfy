#!/bin/bash
set -e

JOURNALCTL_BIN="${JOURNALCTL_BIN:-/usr/bin/journalctl}"
JOURNALCTL_USER="${1:-sshd}"
"$JOURNALCTL_BIN" -D /var/log/journal -S now -fu "$JOURNALCTL_USER"
