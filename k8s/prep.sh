#!/bin/bash -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

read -p "Enter namespace (empty for default): " NAMESPACE

if [ -z "$NAMESPACE" ]; then
    NAMESPACE=default
fi

kubectl apply -f "$HERE"/role.yaml -n "$NAMESPACE"
SECRET_NAME="$(kubectl get serviceaccount logtfy-service-account -o jsonpath='{.secrets[0].name}' -n "$NAMESPACE")"
kubectl get secret "$SECRET_NAME" -o jsonpath='{.data.token}' -n default | base64 --decode > "$HERE"/token
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode > "$HERE"/ca.crt
