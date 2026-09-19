#!/usr/bin/env bash
# In-cluster image registry on NodePort 30500 (game sidecars and apps push here).
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only
cd "$(dirname "${BASH_SOURCE[0]}")/.."

kubectl apply -k registry
kubectl -n registry rollout status deploy/registry --timeout=180s
