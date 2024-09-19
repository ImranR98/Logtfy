#!/bin/bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

NAMESPACE="$1"

if [ -z "$NAMESPACE" ]; then
    read -p "Enter namespace (empty for default): " NAMESPACE
fi

if [ -z "$NAMESPACE" ]; then
    NAMESPACE=default
fi

sed "s/default/$NAMESPACE/g" "$HERE"/role.yaml | kubectl apply -f -
kubectl get -n "$NAMESPACE" secret logtfy-service-account-token -o jsonpath='{.data.token}' | base64 --decode > "$HERE"/token
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode > "$HERE"/ca.crt
