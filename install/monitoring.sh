#!/usr/bin/env bash
# Installs in-cluster Prometheus. Grafana comes from servers-web; VPA is install/vpa.sh.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only
cd "$(dirname "${BASH_SOURCE[0]}")/.."

kubectl apply -f monitoring-config/prometheus-manifests.yaml

echo "Done. Prometheus is on NodePort 30090:"
echo "  curl http://localhost:30090/api/v1/targets"
