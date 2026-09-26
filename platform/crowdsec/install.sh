#!/usr/bin/env bash
# CrowdSec in the crowdsec namespace, plus the Traefik bouncer middleware. Run before Traefik
# loads platform/k3s/traefik-config.yaml, which references the middleware. Safe to re-run.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}" # /etc/rancher/k3s/k3s.yaml is root-only
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

CHART_VERSION=0.24.2

kubectl create namespace crowdsec --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n crowdsec get secret bouncer-key >/dev/null 2>&1; then
  kubectl -n crowdsec create secret generic bouncer-key --from-literal=key="$(openssl rand -hex 32)"
fi

helm repo add crowdsec https://crowdsecurity.github.io/helm-charts >/dev/null
helm repo update crowdsec >/dev/null
helm upgrade --install crowdsec crowdsec/crowdsec --version "$CHART_VERSION" \
  -n crowdsec -f platform/crowdsec/values.yaml --wait --timeout 10m

kubectl apply -f platform/crowdsec/bouncer-middleware.yaml

# Beside the website's own dashboards, in Grafana's Website folder.
kubectl -n crowdsec create configmap crowdsec-dashboards --from-file=platform/crowdsec/grafana/dashboards/ \
  --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 -o yaml \
  | kubectl annotate --local -f - grafana_folder=Website -o yaml \
  | kubectl apply --server-side -f -
