#!/usr/bin/env bash
# Installs Grafana Alloy into the k3s-linuxgsm cluster to ship game pod
# logs to the Loki instance on the webserver VM (192.168.0.200). Requires:
#   1. ./scripts/install-k3s.sh already run.
#   2. The Ingress in external/webserver-vm/loki-ingress.yaml applied on
#      the *webserver VM's* cluster (not this one) -- see that file.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! curl -sf --max-time 3 -o /dev/null http://loki.192.168.0.200.nip.io/ready; then
  echo "WARNING: http://loki.192.168.0.200.nip.io is not responding." >&2
  echo "Has external/webserver-vm/loki-ingress.yaml been applied on the webserver VM's cluster yet?" >&2
fi

helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install alloy-logs grafana/alloy \
  -n monitoring \
  -f monitoring/alloy-logs-values.yaml \
  "$@"

echo "Done. Check games namespace logs are arriving with:"
echo "  kubectl -n monitoring logs -l app.kubernetes.io/name=alloy -f"
