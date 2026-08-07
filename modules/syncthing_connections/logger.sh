#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

CONTAINER_NAME="${1:-syncthing}"
source "$HERE"/../../helpers/stream_docker_logs.sh "$CONTAINER_NAME"
