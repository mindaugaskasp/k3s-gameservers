# Architecture

A single-node k3s cluster runs three namespaces:

- `games`: one StatefulSet per game (`valheim`, `zomboid`, `enshrouded`)
- `monitoring`, `registry`: the platform, see [platform.md](platform.md)
- other namespaces: apps like servers-web, which only report to the platform

## Workloads

- **StatefulSets:** each game is one world, one volume, one pod.
  `helm uninstall` keeps the PVC.
- **Replicas** come from the live object (`lookup`), so `helm upgrade`
  doesn't undo a scale to 0.
- **Deploying:** use
  `helm upgrade <g> charts/<g>-server -n games --reuse-values -f games/<g>/values.override.yaml`
  to keep existing secrets.
- **Secrets** (passwords, Discord webhooks) are set from env vars at deploy
  time and never committed.

## Networking

Game ports are UDP NodePorts on the same numbers the router forwards:

- Valheim: 2456-2458
- Zomboid: 16261-16262, plus RCON on TCP 27015
- Enshrouded: 15637 (game traffic and Steam queries share it)

That's why the NodePort range is widened ([platform.md](platform.md#k3s)).

## Monitoring

- **Player tallies:** the sidecar mounts the game volume read-only apart from
  `players/`, the one path it and the log hooks write.
- **Sidecar:** `game-status-metrics/` queries each game with
  [gamedig](https://github.com/gamedig/node-gamedig) and serves `:9101/metrics`;
  its modules are listed in [status-metrics.md](status-metrics.md).
- **Image tag:** `games/metrics-image.mk` tags the sidecar with the last commit that
  touched its source, so changing it replaces the pod and leaving it alone does not.
- **Metric names:** `valheim_*` for what only Valheim reports, `game_server_*` for
  what every game reports, separated by the `game` label.
- **Prometheus:** plain manifests on NodePort 30090 with 7 days of history.
  It scrapes the sidecars, kubelet and cAdvisor.
- **Dashboards:** `make dashboards` applies `games/<game>/grafana/dashboards/`
  as a labeled ConfigMap ([platform.md](platform.md#reporting-from-an-app)).
- **[VPA](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)**
  (optional): `updateMode: "Off"`, so it only makes recommendations.

## Sizing

- **No CPU limits**, to avoid
  [CFS throttling](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run).
- **One game at a time:** if the node can't fit two games, keep their summed
  requests above allocatable so the second stays `Pending`, not OOM-killing the first.
