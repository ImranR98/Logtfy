#!/bin/bash -e

EXTRA_DATA="$1"

read NAMESPACE SERVICE_NAME <<< "$EXTRA_DATA"

if [ -z "$NAMESPACE" ]; then
    NAMESPACE="default"
fi
if [ -z "$SERVICE_NAME" ]; then
    SERVICE_NAME="traefik"
fi

TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CA_CERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

PODS=$(curl -s --header "Authorization: Bearer $TOKEN" \
    --cacert $CA_CERT \
    "https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/pods?labelSelector=app.kubernetes.io/name=$SERVICE_NAME" |
    jq -r '.items[].metadata.name')

for POD in $PODS; do
    curl -s --header "Authorization: Bearer $TOKEN" \
        --cacert $CA_CERT \
        "https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/pods/$POD/log?follow=true" &
done

wait