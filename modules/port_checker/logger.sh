#!/bin/bash
set -e

EXTRA_DATA="$1"
read HOST PORT SLEEP_TIME <<< "$EXTRA_DATA"

if [ -z "$HOST" ]; then
    HOST="example.org"
fi

if [ -z "$PORT" ]; then
    PORT="443"
fi

if [ -z "$SLEEP_TIME" ]; then
    SLEEP_TIME="300"
fi

IS_FAILING=false

while [ true ]; do
    if ! nc -vz "$HOST" "$PORT" 2>&1; then
        if [ "$IS_FAILING" == false ]; then
            echo "Port $PORT on $HOST is closed!"
            IS_FAILING=true
        fi
    else
        if [ "$IS_FAILING" == true ]; then
            echo "Port $PORT on $HOST is open!"
            IS_FAILING=false
        fi
    fi
    sleep "$SLEEP_TIME"
done