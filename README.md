# k3s-gameservers

Runs game servers as pods on a single-node [k3s](https://k3s.io/) cluster,
with per-pod resource tracking so each game can be right-sized instead of
hand-tuned on bare metal. Currently one server: Valheim.

## Layout

```
charts/valheim-server/   Helm chart -- the deployable unit
games/valheim/           This server's config and day-to-day ops
  values.override.yaml     overrides charts/valheim-server/values.yaml
  Makefile                 deploy, logs, restart, backups, dashboards
  dashboards/              Grafana dashboard JSON
install/                 Run-once setup scripts, in this order
  k3s.sh                      podman + k3s + helm
  monitoring.sh               in-cluster Prometheus (+ VPA)
  log-shipping.sh             Grafana Alloy -> Loki on the webserver VM
monitoring-config/       Config the install scripts apply
  prometheus-manifests.yaml   applied with kubectl, not Helm
  alloy-helm-values.yaml      values for the upstream grafana/alloy chart
game-status-metrics/     Source for the sidecar image that reports player
                         counts and server status as Prometheus metrics
docs/architecture.md     Design rationale and host constraints
```

Nothing here runs automatically. Every script needs `sudo`/cluster access
and is meant to be read before it is run.

## Setup from scratch

```sh
./install/k3s.sh
./install/monitoring.sh
LOKI_URL=http://loki.192.168.0.200.nip.io ./install/log-shipping.sh

cd games/valheim
make import-metrics-image                 # build + load the sidecar image
export VALHEIM_SERVER_PASSWORD=...
make deploy
make status
```

## Day-to-day

Everything runs from `games/valheim/`:

```sh
make help       # all targets
make logs       # tail the gameserver
make players    # current player count
make restart    # rollout restart
make backups    # list backups in the PVC
```

## Backups and restore

The server takes its own backups on `backups.cron` (hourly) and prunes them
by `backups.maxAge` / `backups.maxCount` — all three are set in
`charts/valheim-server/values.yaml`, and whichever limit bites first wins.

The world save, config and backups live on a PVC in the cluster, not in
this repo. Pull a local copy:

```sh
make sync                 # world + config -> data/, archives -> data-backups/
make install-sync-timer   # run that hourly via systemd (on the k3s host)
```

Both directories are gitignored — never commit save data. Local archives
are pruned to the same window the server keeps.

To restore, pick an archive and let the target handle stopping the server:

```sh
ls data-backups
make restore BACKUP=data-backups/<file>.zip
```

It scales the StatefulSet to 0, unpacks the archive over the PVC through a
short-lived helper pod, then scales back up. It asks for confirmation
first, because it replaces the live world.

The Grafana "Backups" row shows how many archives exist, their timestamps
and sizes, total disk used, and when the oldest becomes eligible for
deletion.

Game updates, scheduled restarts and backups are handled **inside the
container** by its own cron settings (`updates`, `restart`, `backups` in
values) — there are no Kubernetes CronJobs.

## Monitoring

Prometheus runs in-cluster on NodePort 30090 and keeps 7 days of history.
Grafana is **not** in this cluster — dashboards live on the webserver VM's
Grafana, which queries this Prometheus. Push dashboard changes with
`make dashboards` (needs `GRAFANA_URL` and `GRAFANA_TOKEN`).

Pod logs ship to that same VM's Loki via Alloy.

## Mods

Off by default. To enable BepInEx, set `mods.enabled=true` in
`games/valheim/values.override.yaml`, put plugin DLLs in
`/config/bepinex/plugins` on the PVC, and redeploy.

```sh
make mods-status    # did mods load, and if not why
make bless-mods     # mark the running game build as verified, then: make restart
```

A Valheim update can arrive before a compatible BepInEx does. When that
happens the server starts **unmodded** and alerts, rather than crash-looping
— see `docs/architecture.md` for how the guard decides.

## Adding another game

Copy `charts/valheim-server` and swap the image and its env vars, then add
a `games/<name>/` with a `values.override.yaml` and a Makefile.
`game-status-metrics/` works for any game — point `GAMEDIG_GAME` at any
[gamedig](https://github.com/gamedig/node-gamedig#games-list) game id.
