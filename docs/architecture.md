# Architecture

A single-node k3s cluster runs three namespaces:

- `games`: one StatefulSet per game (`valheim`, `zomboid`, `enshrouded`)
- `monitoring`, `registry`, `crowdsec`: the platform, see [platform.md](platform.md)
- on the host: ufw lets only SSH, the LAN and pods in, routed game ports aside
  ([platform.md](platform.md)); a timer copies worlds off-host ([offsite-backups.md](offsite-backups.md))
- other namespaces: apps like servers-web, which only report to the platform

## Workloads

- **StatefulSets:** each game is one world, one volume, one pod.
  `helm uninstall` keeps the PVC.
- **Replicas** come from the live object (`lookup`), so `helm upgrade`
  doesn't undo a scale to 0.
- **Deploying:** use
  `helm upgrade <g> games/<g>/chart -n games --reuse-values -f games/<g>/values.override.yaml`
  to keep existing secrets.
- **Secrets** (passwords, Discord webhooks) are set from env vars at deploy
  time and never committed.

## Shared game pieces

`game-server/` holds what every game uses, so a new game is one `games/<game>/` folder:

- **`chart/`:** a Helm [library chart](https://helm.sh/docs/topics/library_charts/) each game's chart
  depends on: helpers, labels, VPA, the Discord secret, the status-metrics sidecar and its Service.
- **`make/game.mk`:** every game's shared make targets; the game Makefile sets its paths and includes it.
- **`status-metrics/`:** the exporter's shared core ([status-metrics.md](status-metrics.md)).
- **`systemd/`, `restore-helper-pod.yaml`:** the hourly sync timer and the restore pod, one per game instance.

## Networking

Game ports are UDP NodePorts on the same numbers the router forwards:

- Valheim: 2456-2458
- Zomboid: 16261-16262, plus RCON on TCP 27015
- Enshrouded: 15637 (game traffic and Steam queries share it)

That's why the NodePort range is widened ([platform.md](platform.md#k3s)).
HTTP goes through Traefik, where CrowdSec bans scanners ([crowdsec.md](crowdsec.md)).

## Monitoring

- **Player history:** `database/sqlite/<game>.db`, its own path on the volume.
  Game images chown their tree to `PUID` on each start, so every game runs as uid 1000,
  the sidecar's user, or the database turns read-only. Only the sidecar writes it.
- **Sidecar:** each game's pod queries its server with [gamedig](https://github.com/gamedig/node-gamedig)
  and serves `:9101/metrics`: `game-server/status-metrics/` shared, `games/<game>/status-metrics/` its own
  ([status-metrics.md](status-metrics.md), [player-database.md](player-database.md)).
- **Image:** `<game>-status-metrics`, tagged by `game-server/make/metrics-image.mk` with the last commit
  touching either folder, so changing one game's exporter replaces only that game's pod.
- **Help:** `make/help.mk` builds `make help [<command>]` from the `## ` lines above each target.
- **Metric names:** `valheim_*` for what only Valheim reports, `game_server_*` for
  what every game reports, separated by the `game` label.
- **Prometheus:** plain manifests, LAN-only Ingress, 7 days of history.
  It scrapes the sidecars, kubelet, cAdvisor and cert-manager.
- **Alerts:** Grafana rules in `platform/monitoring/config/alerting.yaml` post to Discord with links back to Grafana.
- **Dashboards:** `make dashboards` applies `games/<game>/grafana/dashboards/`
  as a labeled ConfigMap ([platform.md](platform.md#reporting-from-an-app)).
- **[VPA](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)**
  (optional): `updateMode: "Off"`, so it only makes recommendations.

## Sizing

- **No CPU limits**, to avoid
  [CFS throttling](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run).
- **One game at a time:** if the node can't fit two games, keep their summed
  requests above allocatable so the second stays `Pending`, not OOM-killing the first.
