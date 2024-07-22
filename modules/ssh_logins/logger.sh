#!/bin/bash -e

EXTRA_DATA="$1"

/usr/bin/journalctl -D /var/log/journal -fu sshd