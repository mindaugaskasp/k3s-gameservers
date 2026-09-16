#!/usr/bin/env bash
set -euo pipefail

if command -v podman >/dev/null 2>&1; then
  echo "podman already installed: $(podman --version)"
else
  echo "Installing podman..."
  sudo apt-get update
  sudo apt-get install -y podman
fi

if command -v k3s >/dev/null 2>&1; then
  echo "k3s already installed: $(k3s --version | head -1)"
else
  echo "Installing k3s..."
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
