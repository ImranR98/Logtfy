#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

EXTRA_DATA="$1"
API_SERVER="${KUBE_API_SERVER}"

if [ -z "$API_SERVER" ]; then
    API_SERVER="https://$(kubectl -n kube-system get pod -l component=kube-apiserver -o=jsonpath="{.items[0].metadata.annotations.kubeadm\.kubernetes\.io/kube-apiserver\.advertise-address\.endpoint}")"
fi

read SERVICE_NAME NAMESPACE <<< "$EXTRA_DATA"

if [ -z "$SERVICE_NAME" ]; then
    echo "Service name not specified!" >&2
    exit 1
fi
: "${NAMESPACE:=default}"

find_file() {
    local filename="$1"
    local local_path="$HERE/../k8s/$filename"
    local sa_path="/var/run/secrets/kubernetes.io/serviceaccount/$filename"
    if [ -f "$local_path" ]; then
        echo "$local_path"
    elif [ -f "$sa_path" ]; then
        echo "$sa_path"
    else
        echo "No $filename file found!" >&2
        exit 1
    fi
}

TOKEN=$(cat "$(find_file token)")
CA_CERT=$(find_file ca.crt)

CURL_AUTH=(--header "Authorization: Bearer $TOKEN" --cacert "$CA_CERT")

while true; do
    PODS=$(curl -s "${CURL_AUTH[@]}" \
        "$API_SERVER/api/v1/namespaces/$NAMESPACE/pods?labelSelector=app.kubernetes.io/name=$SERVICE_NAME" |
        jq -r '.items[].metadata.name')

    if [ -z "$PODS" ]; then
        echo "No pods found!" >&2
        exit 1
    fi

    for POD in $PODS; do
        timeout 3600 curl -s "${CURL_AUTH[@]}" \
            "$API_SERVER/api/v1/namespaces/$NAMESPACE/pods/$POD/log?follow=true&sinceSeconds=3" &
    done

    # Rotate the stream every hour so the kubelet's hard ~4h cap on
    # log-follow connections is never hit. sinceSeconds=3 replays the
    # last 3s on reconnect so no logs are lost in the handoff gap.
    wait || true
done
