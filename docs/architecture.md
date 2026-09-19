# Architecture

A single-node k3s cluster runs three namespaces:

- `games`: one StatefulSet per game (`valheim`, `zomboid`)
- `monitoring`: Prometheus, plus Grafana, Loki and Alloy from servers-web
- `webserver`: the servers-web site, behind Traefik

## Cluster config

`install/k3s.sh` writes these to
[`/etc/rancher/k3s/config.yaml`](https://docs.k3s.io/installation/configuration#configuration-file):

- `node-name: ${NODE_NAME}` (default: short hostname)
- `write-kubeconfig-mode: "600"`
- `service-node-port-range=2456-32767`

Config file, not flags: servers-web re-runs the installer, which rewrites flags.
`kubectl` uses `~/.kube/config`; `/etc/rancher/k3s/k3s.yaml` is root-only.

**Don't rename the node.** `local-path` PVs pin the node name, and that
field is immutable ([k3s storage](https://docs.k3s.io/storage)).

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

That's why the NodePort range is widened.

## Monitoring

- **Sidecar:** `game-status-metrics/` queries each game with
  [gamedig](https://github.com/gamedig/node-gamedig) and serves `:9101/metrics`.
- **Prometheus:** plain manifests on NodePort 30090 with 7 days of history.
  It scrapes the sidecars, kubelet and cAdvisor.
- **Grafana:** provisions that Prometheus with uid `ffyierrb4yl8gd`.
- **[VPA](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)**
  (optional): `updateMode: "Off"`, so it only makes recommendations.

## Sizing

- **No CPU limits**, to avoid
  [CFS throttling](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run).
- **One game at a time:** if the node can't fit two games, keep their summed
  requests above allocatable so the second stays `Pending`, not OOM-killing the first.
