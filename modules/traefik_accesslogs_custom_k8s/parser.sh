#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "$HERE"/../traefik_accesslogs_custom/parser.sh "$1" "$2"
