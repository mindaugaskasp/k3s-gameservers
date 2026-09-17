# Architecture

Valheim runs as a StatefulSet (`valheim`) in the `games` namespace on this
host's single-node k3s cluster, replacing the bare-metal LGSM instance
(now stopped). `charts/linuxgsm-game` still exists for other LGSM games;
Valheim itself does not use it (see below).

## Why not LGSM's own image

`charts/linuxgsm-game` (generic LGSM wrapper, `gameservermanagers/gameserver:vh`)
crashed reproducibly in this cluster's containers: a `NullReferenceException`
in `MagicaCloth2.MagicaWindZone.Awake()` a few seconds after full startup,
every time, even with known-good binaries copied in from the working
bare-metal install. Root cause was never identified. `charts/valheim-server`
uses the community-maintained `ghcr.io/community-valheim-tools/valheim-server`
image instead (env-var configured, no LGSM), which doesn't have the issue.

## Why StatefulSet, not Deployment

One world, one save directory, one process — no meaningful way to run two
replicas of the same world. StatefulSet gives a stable pod identity and a
`volumeClaimTemplate`, making "1 world = 1 volume = 1 pod" explicit.
`replicaCount` is always 1; horizontal scaling doesn't apply here.

## Config and secrets

`games/valheim/values.yaml` holds the real server name/world
name/modifiers (not sensitive). The password is a Kubernetes Secret,
supplied via `--set-string secrets.serverPassword=...` at deploy time
(`games/valheim/Makefile`'s `deploy` target reads it from
`$VALHEIM_SERVER_PASSWORD`) — never committed.

## Networking

Game (2456), query (2457), and RPC (2458) ports are UDP `NodePort`s,
matching the router's existing port-forward from the bare-metal setup.
k8s's default NodePort range (30000-32767) doesn't cover 2456-2458, so
k3s's range was widened via `/etc/rancher/k3s/config.yaml`
(`kube-apiserver-arg: ["service-node-port-range=2456-32767"]`).

## Maintenance

Update/restart/backup scheduling is handled **inside the container** via
cron-format env vars (`UPDATE_CRON`, `RESTART_CRON`, `BACKUPS_CRON`, all
idle-gated) — no k8s CronJobs needed, unlike the LGSM chart.

## Monitoring

A Node.js sidecar (`monitoring/exporter`) queries the game's status port
with [`gamedig`](https://github.com/gamedig/node-gamedig) and serves
Prometheus text format on `:9101/metrics`. `ServiceMonitor`/VPA are in the
chart but disabled in values until `scripts/install-monitoring.sh` runs.

## Resources

Host: 7.7GB RAM, 4 vCPUs (real hardware: one i7-9700K, 8 threads, shared
with TrueNAS). Measured idle usage: ~130m CPU, ~1.5GB RAM. Values request
1 CPU core / 1Gi memory, limit 4Gi memory, no CPU limit (avoids
CFS-throttling scheduling issues). Community guidance for 4 players: 2+
modern cores, 4-6GB RAM as the world grows.
