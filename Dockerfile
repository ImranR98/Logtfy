# Docker CLI is copied from the official image instead of piping get.docker.com
# into a shell. The CLI is a static binary and honours DOCKER_HOST, so modules
# that talk to a Docker socket work the same way.
FROM docker:29-cli@sha256:2357639ad1ea7d0194134bf3292622fd4e562483966ed674e5d7c945b5f3b28d AS docker-cli

FROM node:lts-trixie-slim@sha256:5adad64f9a1fca2d51972caa65983634c8a774eb300d72b20f7f2a0f60368072

# systemd provides /usr/bin/journalctl, used by the ssh_logins module (srv0
# mounts the host journal). The previous get.docker.com install pulled it in
# transitively; install it explicitly instead of relying on that side effect.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        jq \
        netcat-openbsd \
        systemd && \
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
