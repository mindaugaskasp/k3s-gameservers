# k3s-gameservers

Runs game servers as pods in a local single-node [k3s](https://k3s.io/)
cluster, with per-pod resource tracking in Grafana and a path to
right-size CPU/memory per game instead of hand-tuning bare-metal
instances one by one. Two chart shapes are supported:

- `charts/linuxgsm-game/` — generic [LinuxGSM](https://linuxgsm.com/)
  wrapper, config via LGSM's own `.cfg` files.
- `charts/valheim-server/` — for games better served by a purpose-built
  community Docker image (env-var configured). Valheim moved here after
  LGSM's own Valheim install crashed reproducibly in this cluster's
  containers; see `docs/architecture.md`.

See [`docs/architecture.md`](docs/architecture.md) for the design
rationale (why StatefulSet, why VPA not HPA, secrets handling, and —
important — the RAM/disk constraints on this box). See
[`docs/migrating-valheim.md`](docs/migrating-valheim.md) for the checked,
manual procedure to move the live Valheim world into the cluster.

## Layout

```
charts/linuxgsm-game/    Generic LGSM chart: one release = one game pod
                          (StatefulSet + PVC + Service + ServiceMonitor + VPA
                          + player-gated update/restart CronJobs, replacing
                          the bare-metal LGSM maintenance crontab)
charts/valheim-server/   Valheim via the community valheim-server-docker
                          image (built-in update/restart/backup scheduling,
                          env-var config, no LGSM)
games/valheim/            Per-game Helm values, Grafana dashboard, Makefile
monitoring/
  kube-prometheus-values.yaml  Sized-down kube-prometheus-stack values (metrics)
  alloy-logs-values.yaml   Grafana Alloy values: ships games/* pod logs to the
                          existing Loki on the webserver VM (192.168.0.200)
  exporter/                Node.js Prometheus exporter (gamedig-based)
scripts/
  install-k3s.sh           Install podman + k3s + helm (requires sudo)
  install-monitoring.sh    Install kube-prometheus-stack + VPA components
  install-log-shipping.sh  Install Alloy to ship logs to the webserver VM's Loki
  deploy-game.sh           Build exporter image + helm upgrade --install a game
docs/
  architecture.md
  migrating-valheim.md
```

## Quick start

```sh
./scripts/install-k3s.sh
./scripts/install-monitoring.sh          # local Prometheus/Grafana for metrics
./scripts/install-log-shipping.sh        # ships games/* logs to the webserver VM's Loki
                                          # (Loki must already be exposed on that side)

helm upgrade --install valheim charts/valheim-server -n games \
  --set-string secrets.serverPassword="$VALHEIM_SERVER_PASSWORD"

kubectl -n games get pods
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Or, once deployed, use `games/valheim/Makefile` for day-to-day operations
(`make -C games/valheim help`).

None of this runs automatically — every script requires `sudo`/cluster
access and is meant to be reviewed and run by hand.

## Adding another game

**Via LGSM** (`charts/linuxgsm-game`): `mkdir games/<name>`, copy
`games/valheim/values.yaml`'s shape as a starting point, set
`game.shortname`/`game.name` to LGSM's short name for it, `ports`,
`metricsExporter.gamediggame` (must match a
[gamedig](https://github.com/gamedig/node-gamedig#games-list) game id),
and `instanceConfig`.

**Via a dedicated community image** (like `charts/valheim-server`): only
worth a new chart if LGSM's install for that game turns out broken in a
container too. Copy `charts/valheim-server` as a starting point, swap the
image and its env vars.
