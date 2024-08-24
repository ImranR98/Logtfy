#!/bin/bash -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

EXTRA_DATA="$1"
API_SERVER="${KUBE_API_SERVER}" # This should be an env. var.

read SERVICE_NAME NAMESPACE <<< "$EXTRA_DATA"

if [ -z "$SERVICE_NAME" ]; then
    echo "Service name not specified!" >&2
    exit 1
fi
if [ -z "$NAMESPACE" ]; then
    NAMESPACE="default"
fi

if [ -f "$HERE"/../k8s/token ]; then
    TOKEN=$(cat "$HERE"/../k8s/token)
elif [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
    TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
else
    echo "No token file found!" >&2
    exit 1
fi

if [ -f "$HERE"/../k8s/ca.crt ]; then
    CA_CERT="$HERE"/../k8s/ca.crt
elif [ -f /var/run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
    CA_CERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
else
    echo "No ca.crt file found!" >&2
    exit 1
fi

PODS=$(curl -s --header "Authorization: Bearer $TOKEN" \
    --cacert $CA_CERT \
    "$API_SERVER/api/v1/namespaces/$NAMESPACE/pods?labelSelector=app.kubernetes.io/name=$SERVICE_NAME" |
    jq -r '.items[].metadata.name')

for POD in $PODS; do
    curl -s --header "Authorization: Bearer $TOKEN" \
        --cacert $CA_CERT \
        "$API_SERVER/api/v1/namespaces/$NAMESPACE/pods/$POD/log?follow=true" &
done

wait