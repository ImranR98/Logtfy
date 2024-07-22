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
#    -v ./config.json /logtfy/config.json \
#    -ti imranrdev/logtfy