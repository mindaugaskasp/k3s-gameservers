# Game monitoring

How each game reports to the platform ([architecture.md](architecture.md), [platform.md](platform.md)).

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
