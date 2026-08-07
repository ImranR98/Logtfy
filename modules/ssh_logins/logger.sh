#!/bin/bash
set -e

JOURNALCTL_USER="${1:-sshd}"
/usr/bin/journalctl -D /var/log/journal -S now -fu "$JOURNALCTL_USER"
