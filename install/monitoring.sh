#!/usr/bin/env bash
# Installs in-cluster Prometheus and, unless INSTALL_VPA=0, the VPA
# components. No Grafana here; see docs/architecture.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

kubectl apply -f monitoring-config/prometheus-manifests.yaml

if [ "${INSTALL_VPA:-1}" = "1" ] && ! kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
  echo "Installing Vertical Pod Autoscaler components..."
  tmpdir=$(mktemp -d)
  trap 'rm -rf "${tmpdir}"' EXIT
  git clone --depth 1 https://github.com/kubernetes/autoscaler.git "${tmpdir}/autoscaler"
  "${tmpdir}/autoscaler/vertical-pod-autoscaler/hack/vpa-up.sh"
fi

echo "Done. Prometheus is on NodePort 30090:"
echo "  curl http://localhost:30090/api/v1/targets"
