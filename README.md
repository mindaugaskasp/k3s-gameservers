# k3s-linuxgsm

Wraps [LinuxGSM](https://linuxgsm.com/) game servers so each game/world
runs as its own pod in a local single-node [k3s](https://k3s.io/) cluster,
with per-pod resource tracking in Grafana and a path to right-size
CPU/memory per game instead of hand-tuning bare-metal instances one by
one. First candidate: **Valheim** (`vhserver`, currently running on this
host outside Kubernetes).

See [`docs/architecture.md`](docs/architecture.md) for the design
rationale (why StatefulSet, why VPA not HPA, image choice, secrets
handling, and — important — the RAM constraints on this box). See
[`docs/migrating-valheim.md`](docs/migrating-valheim.md) for the checked,
manual procedure to move the live Valheim world into the cluster.

## Layout

```
charts/linuxgsm-game/    Generic Helm chart: one release = one game pod
                          (StatefulSet + PVC + Service + ServiceMonitor + VPA)
games/valheim/            Per-game Helm values + Grafana dashboard
monitoring/
  kube-prometheus-values.yaml  Sized-down kube-prometheus-stack values
  exporter/                Node.js Prometheus exporter (gamedig-based)
scripts/
  install-k3s.sh           Install k3s + helm (requires sudo)
  install-monitoring.sh    Install kube-prometheus-stack + VPA components
  deploy-game.sh           Build exporter image + helm upgrade --install a game
docs/
  architecture.md
  migrating-valheim.md
```

## Quick start

```sh
./scripts/install-k3s.sh
./scripts/install-monitoring.sh
./scripts/deploy-game.sh valheim \
  --set-string secrets.serverpassword="$VALHEIM_SERVER_PASSWORD" \
  --set-string secrets.discordwebhook="$VALHEIM_DISCORD_WEBHOOK"

kubectl -n games get pods
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

None of this runs automatically — every script requires `sudo`/cluster
access and is meant to be reviewed and run by hand. Nothing here has been
applied against the live `vhserver` bare-metal instance; see
`docs/migrating-valheim.md` before doing that.

## Adding another game

1. `mkdir games/<name>` and copy `games/valheim/values.yaml` as a
   starting point.
2. Set `game.shortname`/`game.name` to LGSM's short name for it, `ports`,
   `metricsExporter.gamediggame` (must match a
   [gamedig](https://github.com/gamedig/node-gamedig#games-list) game id),
   and `instanceConfig`.
3. `./scripts/deploy-game.sh <name>`
