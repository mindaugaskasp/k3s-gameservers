#!/usr/bin/env bash
set -euo pipefail

if command -v podman >/dev/null 2>&1; then
  echo "podman already installed: $(podman --version)"
else
  echo "Installing podman..."
  sudo apt-get update
  sudo apt-get install -y podman
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/k3s"

sudo systemctl enable systemd-time-wait-sync.service
sudo install -D -m 644 "$HERE/wait-for-clock.conf" /etc/systemd/system/k3s.service.d/wait-for-clock.conf
sudo rm -f /etc/systemd/system/k3s.service.d/wait-for-time-sync.conf # merged into wait-for-clock.conf
sudo systemctl daemon-reload

# In-cluster registry (registry/) over plain HTTP, for k3s pulls and podman pushes.
sudo install -D -m 644 "$HERE/registries.yaml" /etc/rancher/k3s/registries.yaml
mkdir -p "$HOME/.config/containers/registries.conf.d"
printf '[[registry]]\nlocation = "localhost:30500"\ninsecure = true\n' > "$HOME/.config/containers/registries.conf.d/localhost-30500.conf"

# Traefik must see real client IPs for the lan-only middleware.
sudo install -D -m 644 "$HERE/traefik-config.yaml" /var/lib/rancher/k3s/server/manifests/traefik-config.yaml

# In config.yaml, not installer flags: re-running the k3s installer rewrites flags only.
NODE_NAME="${NODE_NAME:-$(hostname -s)}"
K3S_CONFIG=/etc/rancher/k3s/config.yaml

if command -v k3s >/dev/null 2>&1; then
  echo "k3s already installed: $(k3s --version | head -1)"
  sudo grep -q "^node-name:" "$K3S_CONFIG" 2>/dev/null \
    || echo "WARNING: no node-name in $K3S_CONFIG -- renaming the node breaks local-path PVs, see docs/architecture.md" >&2
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
