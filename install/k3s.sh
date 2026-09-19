#!/usr/bin/env bash
set -euo pipefail

if command -v podman >/dev/null 2>&1; then
  echo "podman already installed: $(podman --version)"
else
  echo "Installing podman..."
  sudo apt-get update
  sudo apt-get install -y podman
fi

# Wait for verified time sync, not just network: a stale boot clock makes
# k3s generate TLS certs that are not yet valid.
sudo systemctl enable systemd-time-wait-sync.service
sudo mkdir -p /etc/systemd/system/k3s.service.d
printf '[Unit]\nWants=time-sync.target\nAfter=time-sync.target\n' | sudo tee /etc/systemd/system/k3s.service.d/wait-for-time-sync.conf >/dev/null
sudo systemctl daemon-reload

# In config.yaml, not installer flags: re-running the k3s installer rewrites flags only.
NODE_NAME="${NODE_NAME:-$(hostname -s)}"
K3S_CONFIG=/etc/rancher/k3s/config.yaml

if command -v k3s >/dev/null 2>&1; then
  echo "k3s already installed: $(k3s --version | head -1)"
  sudo grep -q "^node-name:" "$K3S_CONFIG" 2>/dev/null \
    || echo "WARNING: no node-name in $K3S_CONFIG -- see docs/architecture.md 'Node identity' before adding one" >&2
else
  sudo mkdir -p /etc/rancher/k3s
  sudo tee "$K3S_CONFIG" >/dev/null <<EOF
node-name: ${NODE_NAME}
write-kubeconfig-mode: "600"
kube-apiserver-arg:
  - "service-node-port-range=2456-32767"
EOF
  echo "Installing k3s..."
  curl -sfL https://get.k3s.io | sh -
fi

mkdir -p "${HOME}/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/config"
sudo chown "$(id -u):$(id -g)" "${HOME}/.kube/config"
chmod 600 "${HOME}/.kube/config"
export KUBECONFIG="${HOME}/.kube/config"
echo "kubeconfig written to ${HOME}/.kube/config"

if ! command -v helm >/dev/null 2>&1; then
  echo "Installing Helm..."
  curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "Waiting for node to be Ready..."
kubectl wait --for=condition=Ready node --all --timeout=120s

kubectl get nodes -o wide
echo "k3s is up. Metrics-server ships with k3s by default (kubectl top nodes/pods)."
