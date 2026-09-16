#!/usr/bin/env bash
# Installs kube-prometheus-stack (Prometheus + Grafana + kube-state-metrics
# + node-exporter, no Alertmanager) and the Kubernetes VPA components into
# the running k3s cluster. Requires ./scripts/install-k3s.sh to have been
# run first (kubectl/helm configured against the cluster).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo update >/dev/null

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/kube-prometheus-values.yaml \
  "$@"

# Vertical Pod Autoscaler: not bundled with k3s or kube-prometheus-stack.
# Uses the upstream install script from kubernetes/autoscaler, which sets
# up the CRDs + recommender/updater/admission-controller deployments in
# the kube-system namespace.
if ! kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
  echo "Installing Vertical Pod Autoscaler CRDs/components..."
  tmpdir=$(mktemp -d)
  trap 'rm -rf "${tmpdir}"' EXIT
  git clone --depth 1 https://github.com/kubernetes/autoscaler.git "${tmpdir}/autoscaler"
  "${tmpdir}/autoscaler/vertical-pod-autoscaler/hack/vpa-up.sh"
else
  echo "VPA CRDs already present, skipping."
fi

echo "Done. Grafana: kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
