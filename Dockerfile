# Docker CLI is copied from the official image instead of piping get.docker.com
# into a shell. The CLI is a static binary and honours DOCKER_HOST, so modules
# that talk to a Docker socket work the same way.
FROM docker:29-cli@sha256:5e6baf67325a79f64ed3bed6863954d5e05d0f3d4e57cbdb14809346814bbfdb AS docker-cli

FROM node:lts-bookworm-slim@sha256:55fb5f5a527ea2c5c4a95f963e48ef90aa38c7b346054fdc8ee9957a2b55d205

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        jq \
        netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

COPY --from=docker-cli /usr/local/bin/docker /usr/bin/docker

WORKDIR /logtfy
COPY . /logtfy

ENTRYPOINT ["./run.sh"]

# Images are published by .github/workflows/ci.yml:
#   ghcr.io/imranr98/logtfy:latest
#   ghcr.io/imranr98/logtfy:sha-<commit>

# docker build -t ghcr.io/imranr98/logtfy .

# docker run \
#    -v /var/log/journal:/var/log/journal:ro \ # For modules that use journalctl
#    -v /var/run/docker.sock:/var/run/docker.sock \ # For modules that use Docker
#    -v ./k8s/token:/logtfy/k8s/token \ # For modules that use K8s (run k8s/prep.sh first)
#    -v ./k8s/ca.crt:/logtfy/k8s/ca.crt \ # For modules that use K8s (run k8s/prep.sh first)
#    -e "KUBE_API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
#    -v ./config.json:/logtfy/config.json \
#    -ti ghcr.io/imranr98/logtfy:latest

# docker run -v ./config.json:/logtfy/config.json -ti ghcr.io/imranr98/logtfy:latest
