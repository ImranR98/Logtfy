FROM node:latest

RUN apt update && \
    apt install -qy curl && \
    curl -sSL https://get.docker.com/ | sh

WORKDIR /logtfy
COPY . /logtfy

ENTRYPOINT ["bash", "run.sh"]

# docker build -t imranrdev/logtfy .

# docker run \
#    -v /var/log/journal:/var/log/journal:ro \ # For modules that use journalctl
#    -v /var/run/docker.sock:/var/run/docker.sock \ # For modules that use Docker
#    -v ./k8s/token:/var/run/secrets/kubernetes.io/serviceaccount/token \ # For modules that use K8s (run k8s/prep.sh first)
#    -v ./k8s/ca.crt:/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \ # For modules that use K8s (run k8s/prep.sh first)
#    -v ./config.json /logtfy/config.json \
#    -ti imranrdev/logtfy