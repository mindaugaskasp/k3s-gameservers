#!/usr/bin/env bash
# n8n in the n8n namespace, SQLite on a local-path volume. Needs infrastructure/site.env.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

[ -f infrastructure/site.env ] || { echo "Missing infrastructure/site.env, copy it from site.env.example" >&2; exit 1; }
grep -q '^N8N_HOST=.' infrastructure/site.env || { echo "Missing N8N_HOST in infrastructure/site.env" >&2; exit 1; }

kubectl apply -f infrastructure/n8n/namespace.yaml
# Created once: a new key would make every saved credential unreadable.
if ! kubectl -n n8n get secret n8n-encryption-key >/dev/null 2>&1; then
  kubectl -n n8n create secret generic n8n-encryption-key --from-literal=key="$(openssl rand -hex 32)"
fi

# site.env sits outside the kustomization, like monitoring's.
kubectl kustomize --load-restrictor LoadRestrictionsNone infrastructure/n8n | kubectl apply -f -
kubectl -n n8n rollout status deploy/n8n --timeout=300s
echo "n8n ready at http://$(sed -n 's/^N8N_HOST=//p' infrastructure/site.env)/"
