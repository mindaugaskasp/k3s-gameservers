# Architecture

Valheim runs as a StatefulSet (`valheim`) in the `games` namespace on a
single-node k3s cluster, replacing a bare-metal LinuxGSM instance that has
since been retired.

## Why not LinuxGSM's own image

The first attempt wrapped `gameservermanagers/gameserver:vh`. It crashed
reproducibly a few seconds after startup with a `NullReferenceException` in
`MagicaCloth2.MagicaWindZone.Awake()` — even with known-good binaries copied
in from the working bare-metal install. Root cause was never found. The
chart now uses the community
[`valheim-server-docker`](https://github.com/community-valheim-tools/valheim-server-docker)
image, which does not have the issue.

## Why StatefulSet, not Deployment

One world, one save directory, one process. There is no meaningful way to
run two replicas of the same world, so `replicas` is fixed at 1. The
StatefulSet gives a stable pod identity and a `volumeClaimTemplate`, which
makes "1 world = 1 volume = 1 pod" explicit. Horizontal scaling does not
apply; vertical (VPA) does.

## Config and secrets

`games/valheim/values.override.yaml` holds the non-sensitive settings —
server name, world name, modifiers — and overrides the chart defaults in
`charts/valheim-server/values.yaml`.

The password is a Kubernetes Secret, supplied at deploy time via
`--set-string secrets.serverPassword=...`; the Makefile reads it from
`$VALHEIM_SERVER_PASSWORD`. The Discord webhook works the same way. Neither
is ever committed. Both can instead point at a pre-existing Secret via
`secretRef`.

## Networking

Game (2456), query (2457) and RPC (2458) are UDP NodePorts, matching the
router's existing port-forward from the bare-metal setup. Kubernetes'
default NodePort range (30000-32767) does not cover these, so k3s's range
was widened in `/etc/rancher/k3s/config.yaml`:

```yaml
kube-apiserver-arg:
  - "service-node-port-range=2456-32767"
```

This is host state, not in this repo — a rebuilt host needs it reapplied.

## World data

The world save and server config live on the PVC at `/config` inside the
pod (`/config/worlds_local` for the save itself); the game install is on a
separate subPath at `/opt/valheim` and is disposable. The PVC is created by
the StatefulSet's `volumeClaimTemplate` and is **not** removed by
`helm uninstall`.

`make sync` pulls a read-only copy into `games/valheim/data/` and
`data-backups/`, both gitignored. `make install-sync-timer` runs that
hourly from a systemd timer on the k3s host — the pod cannot write to a
working copy itself, so the pull is driven from outside.

`make restore BACKUP=...` is the only path that writes back. It scales the
StatefulSet to 0, mounts the PVC in a helper pod
(`games/valheim/restore-helper-pod.yaml`), unpacks the archive over
`/config`, then scales back up. Restoring into a running server would be
overwritten by the next world save, hence the stop.

Backup retention is the server's own (`backups.cron`, `maxAge`,
`maxCount`); the status-metrics sidecar reads `/config/backups` read-only
and reports count, per-file size and timestamp, total bytes and the
oldest archive's expiry as `game_server_backup_*` metrics.

## Mods (BepInEx)

Off by default (`mods.enabled`). When on, the image installs BepInEx itself
and re-merges it over vanilla after every Steam update; plugin DLLs go in
`/config/bepinex/plugins` on the PVC. For admin cheat commands the mod is
[Server Devcommands](https://thunderstore.io/c/valheim/p/JereKuusela/Server_devcommands/),
which gates on `/config/adminlist.txt` — note the admin's *client* needs it
installed too, not just the server.

The image pulls BepInEx from Thunderstore unpinned, so a Valheim update can
land before a compatible BepInEx does. `mod-guard.sh` runs as
`PRE_SERVER_RUN_HOOK` and starts the server unmodded rather than letting it
crash-loop, when either:

- `libdoorstop` is missing or has unresolved libraries (this is what a
  BepInEx build needing a newer GLIBC than the image looks like), or
- the Steam build ID differs from `/config/mods-blessed-build`, i.e. the
  game updated and nobody has confirmed the mods still work.

Degrading clears both `DOORSTOP_ENABLED` and `SERVER_LD_PRELOAD`. Clearing
only the first would still `LD_PRELOAD` an unloadable library and still kill
the server. It posts a Discord alert and exports
`game_server_mods_active` so a silent fallback is visible.

The hook is **sourced, not executed** (`. /etc/valheim-hooks/mod-guard.sh`).
It has to mutate variables in the server script's own shell; run as a child
process it would report success and change nothing.

Re-enable with `make bless-mods` after verifying a modded start, then
`make restart`.

## Maintenance

Updates, restarts and backups are scheduled **inside the container** by
`UPDATE_CRON` / `RESTART_CRON` / `BACKUPS_CRON`, all idle-gated so they
never interrupt active play. There are no Kubernetes CronJobs.

## Monitoring

A Node.js sidecar (`game-status-metrics/`) queries the game's status port with
[gamedig](https://github.com/gamedig/node-gamedig) and serves Prometheus
text on `:9101/metrics`. Lifecycle hooks in the chart write
started/updated timestamps and the Steam build ID to a shared volume for
the exporter to read, since gamedig cannot see any of that.

Lifetime uptime is accumulated into a file on the PVC because Prometheus
only retains 7 days and so cannot answer it from history alone.

Prometheus itself runs in-cluster
(`monitoring-config/prometheus-manifests.yaml`, plain manifests rather than
Helm) on NodePort 30090. Grafana is deliberately not deployed here — the webserver VM
already runs one, and it queries this Prometheus and receives pod logs via
Loki. That keeps this box spending its RAM on the game.

VPA is installed by `install/monitoring.sh` but left disabled in
values; enable it in `updateMode: "Off"` to get sizing recommendations
without evictions.

## Resources

Host: 7.7GB RAM, 4 vCPUs (one i7-9700K, 8 threads, shared with TrueNAS).
Measured idle: ~130m CPU, ~1.5GB RAM. Values request 1 core / 1Gi, limit
4Gi memory, and set no CPU limit to avoid CFS throttling. Community
guidance for four players is 2+ modern cores and 4-6GB RAM as the world
grows, which is close to this box's ceiling.
