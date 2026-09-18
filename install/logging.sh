#!/usr/bin/env bash
# Ships games/* pod logs to the webserver VM's Loki via Grafana Alloy.
# Needs install/k3s.sh first.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Local, gitignored -- put LOKI_URL=http://loki.<host> here so it isn't
# committed (same pattern as VM_HOST/GRAFANA_TOKEN in the root Makefile).
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [ -z "${LOKI_URL:-}" ]; then
  echo "LOKI_URL is not set -- add LOKI_URL=http://loki.<host> to a local .env" >&2
  echo "(gitignored), or pass it directly: LOKI_URL=http://loki.<host> $0" >&2
  exit 1
fi
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
