#!/bin/bash -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source "$HERE"/../traefik_geoblock_allowed_requests/parser.sh