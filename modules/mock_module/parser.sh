#!/bin/bash
set -e

LOG_LINE="$1"
EXTRA_DATA="$2"

DIVISIBLE_BY=5

i="$(echo "$LOG_LINE" | awk '{print $NF}')"
if [ $(($i % $DIVISIBLE_BY)) -eq 0 ]; then
    echo "Mock log on $(hostname -f)


Mock log number $i is divisible by $DIVISIBLE_BY"
fi