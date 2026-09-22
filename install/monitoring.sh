#!/usr/bin/env bash
# Prometheus, Loki, Alloy and Grafana in the monitoring namespace. Needs monitoring/.env.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only
cd "$(dirname "${BASH_SOURCE[0]}")/.."

[ -f monitoring/.env ] || { echo "Missing monitoring/.env, copy it from .env.example" >&2; exit 1; }

kubectl apply -f monitoring/namespace.yaml
if ! kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1; then
  kubectl -n monitoring create secret generic grafana-admin --from-literal=password="$(openssl rand -base64 24)"
fi

webhook=$(sed -n 's/^ALERTS_DISCORD_WEBHOOK_URL=//p' monitoring/.env)
[ -n "$webhook" ] || { echo "Missing ALERTS_DISCORD_WEBHOOK_URL in monitoring/.env" >&2; exit 1; }
kubectl -n monitoring create secret generic grafana-alerts --from-literal=discord-webhook-url="$webhook" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -k monitoring
kubectl -n monitoring rollout status deploy/grafana --timeout=300s
echo "Grafana admin password: make -s grafana-password"
