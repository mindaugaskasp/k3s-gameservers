#!/usr/bin/env bash
# Installs a single-node k3s server plus Helm. Idempotent-ish: safe to
# re-run, but does NOT uninstall or reset an existing cluster.
#
# Requires sudo. Not run automatically by anything in this repo -- review
# it, then run by hand:
#   ./scripts/install-k3s.sh
set -euo pipefail

if command -v k3s >/dev/null 2>&1; then
  echo "k3s already installed: $(k3s --version | head -1)"
else
  echo "Installing k3s (disabling the bundled traefik ingress; not needed for UDP game traffic)..."
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -
fi

mkdir -p "${HOME}/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/config"
sudo chown "$(id -u):$(id -g)" "${HOME}/.kube/config"
echo "kubeconfig written to ${HOME}/.kube/config"

if ! command -v helm >/dev/null 2>&1; then
  echo "Installing Helm..."
  curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "Waiting for node to be Ready..."
kubectl wait --for=condition=Ready node --all --timeout=120s

kubectl get nodes -o wide
echo "k3s is up. Metrics-server ships with k3s by default (kubectl top nodes/pods)."
