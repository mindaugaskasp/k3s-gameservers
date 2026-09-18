#!/usr/bin/env bash
# Ships games/* pod logs to the webserver VM's Loki via Grafana Alloy.
# Needs install/k3s.sh first; override the endpoint with $LOKI_URL.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

LOKI_URL="${LOKI_URL:-http://loki.192.168.0.200.nip.io}"
LOKI_URL="${LOKI_URL%/}"

if ! curl -sf --max-time 3 -o /dev/null "${LOKI_URL}/ready"; then
  echo "WARNING: ${LOKI_URL} is not responding; logs will queue until it is." >&2
fi

rendered=$(mktemp)
trap 'rm -f "${rendered}"' EXIT
sed "s|__LOKI_PUSH_URL__|${LOKI_URL}/loki/api/v1/push|g" \
  monitoring-config/alloy-helm-values.yaml > "${rendered}"

helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install alloy-logs grafana/alloy \
  -n monitoring \
  -f "${rendered}" \
  "$@"

echo "Done. Shipping to ${LOKI_URL}. Check with:"
echo "  kubectl -n monitoring logs -l app.kubernetes.io/name=alloy -f"
