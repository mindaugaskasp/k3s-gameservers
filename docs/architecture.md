# Architecture

A single-node k3s cluster (node `kubernetes-vm`, 192.168.0.129). Game servers
run in the `games` namespace, one StatefulSet each (`valheim`, `zomboid`).
Prometheus runs in `monitoring`. The servers-web site (a separate repo) shares
the cluster in its own namespace behind Traefik.

## Cluster setup

`install/k3s.sh` writes `/etc/rancher/k3s/config.yaml` before installing:

```yaml
node-name: kubernetes-vm
write-kubeconfig-mode: "600"
kube-apiserver-arg:
  - "service-node-port-range=2456-32767"
```

These live in config.yaml rather than installer flags because servers-web's
`cluster-setup/install.sh` re-runs the k3s installer on this box, which
replaces the flags but leaves config.yaml alone. Traefik is left enabled
because the site needs it.

The kubeconfig at `/etc/rancher/k3s/k3s.yaml` is root-only. The install
scripts and Makefiles default `KUBECONFIG` to `~/.kube/config`. `kubectl`
here is k3s's own binary, and without that variable it reads the
root-only file.

**Node identity.** The node name is pinned instead of following the
hostname. `local-path` PVs pin `nodeAffinity` to the node name when they are
created, and the field is immutable. The node used to be named `valheim`.
When the host was renamed, every PV (Valheim, Zomboid, Prometheus) had to be
recreated by hand: reclaim policy set to `Retain`, PV/PVC deleted, then
recreated with `volumeName` pinned to the same on-disk path. Renaming the
node again means repeating that for every PVC.

## Why StatefulSet

One world, one save directory, one process. `replicas` is fixed at 1, and
the `volumeClaimTemplate` makes "1 world = 1 volume = 1 pod" explicit.
Vertical scaling (VPA) applies, horizontal doesn't. `helm uninstall` keeps
the PVC.

## Config and secrets

`games/<game>/values.override.yaml` holds non-sensitive settings. Passwords
and Discord webhooks are Kubernetes Secrets set at deploy time from env vars
(or a gitignored `games/<game>/.env`), or from an existing Secret via
`secretRef`. They are never committed.

## Networking

Game ports are UDP NodePorts on the same numbers the router already
forwards: Valheim 2456-2458, Zomboid 16261-16262, plus Zomboid RCON on TCP
27015. The widened NodePort range above is what allows ports below 30000.

## Valheim

Uses the community
[`valheim-server-docker`](https://github.com/community-valheim-tools/valheim-server-docker)
image. LinuxGSM's `gameserver:vh` image crashed a few seconds after startup
in `MagicaCloth2.MagicaWindZone.Awake()`, and the cause was never found.

The world and config are on the PVC at `/config` (the save itself is in
`worlds_local`). The game install is on a disposable subPath at
`/opt/valheim`. The image schedules its own updates (every 15 minutes),
restart (05:10) and hourly backups, all idle-gated and all in UTC.

**Who's online.** Valheim's query protocol reports a player count, not names. The
image's `ON_VALHEIM_LOG_FILTER_*` hooks run `player-event.sh` on three log lines:
`Got handshake from client <SteamID>`, `Got character ZDOID from <Name> : <id>`
(where `0:0` is a death) and `Closing socket <SteamID>`. It keeps one file per
online character under `/var/run/valheim-status/players/online`, and the sidecar
exports these as `game_server_player_online{name}`. The sidecar also clears them
whenever the server reports 0 players, so a missed disconnect can't leave a
name behind.

**Mods (BepInEx)** are off by default. When enabled, plugin DLLs go in
`/config/bepinex/plugins`. The image pulls BepInEx unpinned, so a Valheim
update can land before a compatible BepInEx does. `mod-guard.sh` runs as a
*sourced* `PRE_SERVER_RUN_HOOK` and starts the server unmodded instead of
letting it crash-loop in either of these cases:

- `libdoorstop` is missing or has unresolved libraries
- the Steam build differs from `/config/mods-approved-build`

It clears both `DOORSTOP_ENABLED` and `SERVER_LD_PRELOAD`, sends an alert and
exports `game_server_mods_active`. After checking that a modded start works,
re-enable with `make approve-mods` and then `make restart`. Admin commands
come from Server Devcommands, which the admin's own client needs as well.

## Project Zomboid

Built on `terule/pz-dedicated-server`. The chart follows what the image's
`entrypoint.sh` actually reads; its README and `.env.example` disagree with
it on port variable names. Differences from Valheim:

- **Names.** `server.name` names the save, ini and db files, and must not
  contain spaces (the chart refuses). PZ saves the world as
  `name_with_underscores` but backs it up by the raw name, so with a space
  in the name the game's backups silently skipped the world.
  `server.displayName` becomes the browser name (`PublicName`).
- **ini settings.** `entrypoint.sh` patches only its own set of keys. An
  initContainer sets `PublicName` and the `Backups*` keys before the game
  reads the ini. On a brand-new volume these only apply from the second
  boot, because there is no ini on the first.
- **Backups** use the game's own `ZipBackup`, writing to
  `/project-zomboid-config/backups/{period,startup,version}/backup_N.zip`,
  where 1 is the newest and `backups.count` is kept per type. Periodic
  backups run hourly. A backup is also taken on every start and before a
  version change. The version-change backup matters because Build 42 saves
  don't survive some updates. Each zip holds `Saves/Multiplayer/<name>`,
  `Server/`, `db/` and `options.ini`. `make restore-backup` swaps back only
  those paths, and it refuses a zip that contains no world.
- **Updates.** The image runs steamcmd on every start, so updating means
  restarting. The `zomboid-update` CronJob (05:00 UTC) asks RCON how many
  players are online and restarts the StatefulSet only if there are none.
  Its ServiceAccount can only exec into pods and patch this one StatefulSet.
- **Alerts.** The image has no hook system, so Discord alerts run from
  Kubernetes `postStart`/`preStop` hooks. `postStart` must return quickly
  (kubelet holds the container out of Running until it does), so it starts
  a background poller. The poller waits for RCON, then compares the Steam
  build (appid 380870) with the previous one to tell a plain start from an
  update.
- **Probes** run `pgrep ProjectZomboid`, the same check as the image's
  Dockerfile `HEALTHCHECK`. There's no HTTP status endpoint.
- **RCON.** The binary is `rcon`, not `rcon-cli`. Each argument is a
  separate command, so a command and its argument go in as one string:
  `rcon ... "servermsg \"hi\""`.
- **Admins** can't be pre-authorized by Steam ID. PZ grants admin with
  `/setaccesslevel <user> admin` to a player who already exists in its
  database, and `addsteamid` only manages the join whitelist.
  `ADMIN_USERNAME`/`ADMIN_PASSWORD` is the way in from the start.
- **Memory.** PZ runs on ZGC, which backs the whole heap with shared memory
  and commits it up front. The container's footprint is about `Xmx + 1GB`,
  not `Xmx`.

## Monitoring

The `game-status-metrics/` sidecar queries each game with
[gamedig](https://github.com/gamedig/node-gamedig) (Zomboid answers A2S on
its game port, Valheim on port+1). It serves `:9101/metrics`, adding lifecycle
timestamps, the build ID and backup stats from files on shared and PVC
volumes. Lifetime uptime is kept on the PVC because Prometheus only retains
7 days.

Prometheus is plain manifests (`monitoring-config/prometheus-manifests.yaml`)
on NodePort 30090. It scrapes both exporters plus the kubelet and cAdvisor.
Grafana, Loki and Alloy come from servers-web's logging stack in the same
`monitoring` namespace. Its Grafana provisions this Prometheus with uid
`ffyierrb4yl8gd`, which the game dashboards reference. Zomboid's chat, user
and PerkLog files reach Loki through the chart's `game-logs` sidecar. VPA
(`install/vpa.sh`) is opt-in and runs in `updateMode: "Off"`, so it only
makes recommendations.

## Resources

Host: 4 vCPUs of an i7-9700K shared with TrueNAS, and 5.8GB allocatable.
There's no CPU limit anywhere, to avoid CFS throttling. On this RAM,
Valheim (~1.7GB) and Zomboid (~3.2GB with a 2GB heap) can't run at the same
time; scale one down with `make scale-down-zero`. Revisit the sizing after
the planned +32GB upgrade.
