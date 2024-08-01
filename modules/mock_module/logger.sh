#!/bin/bash -e

EXTRA_DATA="$1"

i=0
while [ true ]; do
    i=$((i + 1))
    echo "Mock log $i"
    sleep 5
done