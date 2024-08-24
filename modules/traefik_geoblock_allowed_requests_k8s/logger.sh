#!/bin/bash -e

EXTRA_DATA="$1"
API_SERVER="${KUBE_API_SERVER}" # This should be an env. var.

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
    "$API_SERVER/api/v1/namespaces/$NAMESPACE/pods?labelSelector=app.kubernetes.io/name=$SERVICE_NAME" |
    jq -r '.items[].metadata.name')

for POD in $PODS; do
    curl -s --header "Authorization: Bearer $TOKEN" \
        --cacert $CA_CERT \
        "$API_SERVER/api/v1/namespaces/$NAMESPACE/pods/$POD/log?follow=true" &
done

wait