#!/usr/bin/env bash
# Installs in-cluster Prometheus. No Grafana here; see docs/architecture.md.
# For the Vertical Pod Autoscaler, see install/vpa.sh (separate: it clones
# third-party code and installs a cluster-wide admission webhook).
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only
cd "$(dirname "${BASH_SOURCE[0]}")/.."

kubectl apply -f monitoring-config/prometheus-manifests.yaml

echo "Done. Prometheus is on NodePort 30090:"
echo "  curl http://localhost:30090/api/v1/targets"
