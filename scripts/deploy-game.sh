#!/usr/bin/env bash
# Deploys (or upgrades) one game from games/<name>/ using the shared
# charts/linuxgsm-game chart, and wires its Grafana dashboard (if any) into
# the kube-prometheus-stack Grafana sidecar.
#
# Usage:
#   ./scripts/deploy-game.sh valheim \
#     --set-string secrets.serverpassword="$VALHEIM_SERVER_PASSWORD" \
#     --set-string secrets.discordwebhook="$VALHEIM_DISCORD_WEBHOOK"
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

game="${1:?usage: deploy-game.sh <game-name> [extra helm args...]}"
shift || true
game_dir="games/${game}"

if [ ! -f "${game_dir}/values.yaml" ]; then
  echo "No such game: ${game_dir}/values.yaml not found" >&2
  exit 1
fi

kubectl create namespace games --dry-run=client -o yaml | kubectl apply -f -

if [ -f "monitoring/exporter/Dockerfile" ] && command -v docker >/dev/null 2>&1; then
  echo "Building lgsm-exporter image..."
  docker build -t k3s-linuxgsm/lgsm-exporter:latest monitoring/exporter
  # k3s uses containerd, not the docker daemon's store; hand the image
  # across directly instead of requiring a registry.
  if command -v k3s >/dev/null 2>&1; then
    docker save k3s-linuxgsm/lgsm-exporter:latest | sudo k3s ctr images import -
  fi
else
  echo "docker not found or exporter Dockerfile missing; assuming k3s-linuxgsm/lgsm-exporter:latest is already available to the cluster." >&2
fi

helm upgrade --install "${game}" charts/linuxgsm-game \
  -f "${game_dir}/values.yaml" \
  -n games \
  "$@"

dashboard_json="${game_dir}/grafana-dashboard.json"
if [ -f "${dashboard_json}" ]; then
  kubectl -n games create configmap "${game}-grafana-dashboard" \
    --from-file=dashboard.json="${dashboard_json}" \
    --dry-run=client -o yaml \
    | kubectl label -f - --local -o yaml grafana_dashboard="1" \
    | kubectl apply -f -
fi

echo "Deployed ${game}. See: kubectl -n games get pods -l app.kubernetes.io/instance=${game}"
