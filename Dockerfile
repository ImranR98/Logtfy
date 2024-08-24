FROM node:latest

RUN apt update && \
    apt install -qy curl jq && \
    curl -sSL https://get.docker.com/ | sh

WORKDIR /logtfy
COPY . /logtfy

ENTRYPOINT ["./run.sh"]

# docker build -t imranrdev/logtfy .

# docker run \
#    -v /var/log/journal:/var/log/journal:ro \ # For modules that use journalctl
#    -v /var/run/docker.sock:/var/run/docker.sock \ # For modules that use Docker
#    -v ./k8s/token:/logtfy/k8s/token \ # For modules that use K8s (run k8s/prep.sh first)
#    -v ./k8s/ca.crt:/logtfy/k8s/ca.crt \ # For modules that use K8s (run k8s/prep.sh first)
#    -e "KUBE_API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
#    -v ./config.json:/logtfy/config.json \
#    -ti imranrdev/logtfy
