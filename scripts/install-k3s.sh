#!/usr/bin/env bash
set -euo pipefail

if command -v podman >/dev/null 2>&1; then
  echo "podman already installed: $(podman --version)"
else
  echo "Installing podman..."
  sudo apt-get update
  sudo apt-get install -y podman
fi

# systemd-timesyncd only marks time-set.target (clock set, not verified
# synced) before k3s's default network-online.target dependency. If the
# VM's RTC is stale/wrong at boot (e.g. after being powered off for a
# host-side disk resize), k3s can start and mint its TLS certs before NTP
# has actually corrected the clock -- and since k3s persists those certs
# in its datastore, a bad timestamp baked in at boot keeps getting reused
# across restarts until real time catches up to it. Forcing k3s to wait
# on time-sync.target (only reached once NTP sync is confirmed) prevents
# this class of bug outright. See docs/architecture.md for the incident
# this was found from.
sudo systemctl enable systemd-time-wait-sync.service
sudo mkdir -p /etc/systemd/system/k3s.service.d
printf '[Unit]\nWants=time-sync.target\nAfter=time-sync.target\n' | sudo tee /etc/systemd/system/k3s.service.d/wait-for-time-sync.conf >/dev/null
sudo systemctl daemon-reload

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
