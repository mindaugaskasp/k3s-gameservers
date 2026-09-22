# Platform

This repo owns the cluster. Apps (e.g. servers-web) only deploy into
their own namespace and report to it.

| Piece | Where | Install |
|---|---|---|
| k3s, Traefik config, registry mirror, clock drop-in | `install/k3s/` | `install/k3s.sh` |
| Image registry, localhost:30500 only | `registry/` | `install/registry.sh` |
| Prometheus, Loki, Alloy, Grafana | `monitoring/` | `install/monitoring.sh` |
| Stuck-pod cleanup CronJob (every 5 min) | `maintenance/` | `make maintenance` |
| Off-host backups, rclone ([offsite-backups.md](offsite-backups.md)) | `offsite-backup/` | `make install-offsite-backup-timer` |

## k3s

`install/k3s.sh` writes
[`/etc/rancher/k3s/config.yaml`](https://docs.k3s.io/installation/configuration#configuration-file):
`node-name` (default: short hostname), `write-kubeconfig-mode: "600"`,
and `service-node-port-range=2456-32767`. Re-running the installer rewrites
flags, not this file. `kubectl` uses `~/.kube/config`.

**Don't rename the node.** `local-path` PVs pin the node name, and that
field is immutable ([k3s storage](https://docs.k3s.io/storage)).

Traefik runs with `externalTrafficPolicy: Local`
([HelmChartConfig](https://docs.k3s.io/add-ons/helm#customizing-packaged-components-with-helmchartconfig)),
so middlewares see real client IPs.

**After a reboot**, containerd can leave pods in `CreateContainerError`
("failed to reserve container name"). The kubelet's retries reuse the
reserved name, so they never succeed. `maintenance/` deletes such pods if a
controller owns them, and the controller recreates them.

## Monitoring

- **Host values** (Grafana/Loki/Prometheus hostnames, LAN CIDR) go in the gitignored
  `monitoring/.env` (see `.env.example`).
- **Access:** Grafana, Prometheus and Loki's push path are LAN-only, via the
  `monitoring-lan-only@kubernetescrd` Traefik middleware.
- **Admin password:** `make grafana-password`.
- **Logs:** Alloy ships every pod's stdout/stderr to Loki (7 days). Loki has
  no auth.
- **Datasources:** Loki (uid `loki`) and Prometheus (uid `ffyierrb4yl8gd`).

## Reporting from an app

An app never edits Grafana, Loki or their ingresses. It only:

1. **Logs** to stdout (JSON lines parse with `| json`).
2. **Ships dashboards** as a ConfigMap in its own namespace, labeled
   `grafana_dashboard: "1"`, with the annotation `grafana_folder: <folder>`.
   The [k8s-sidecar](https://github.com/kiwigrid/k8s-sidecar) loads them.
   Grafana UI edits aren't saved; export the JSON to the repo instead.
3. **Pushes images** to `localhost:30500/<app>/<image>`.

Machines outside the cluster push logs to `http://$LOKI_HOST/loki/api/v1/push`
(e.g. [Alloy](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.write/)).
