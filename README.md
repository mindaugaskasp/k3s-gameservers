# k3s-gameservers

Runs game servers as pods on a single-node [k3s](https://k3s.io/) cluster,
with per-pod resource tracking so each game can be right-sized instead of
hand-tuned on bare metal. Two servers: Valheim and Project Zomboid. Until the
host's RAM upgrade, only one runs at a time (`make scale-down-zero` /
`make scale-up` in `games/<game>/`).

## Layout

```
Makefile                 copy-to-vm / copy-to-host -- run from your own
                         machine, not the VM (see below)
charts/valheim-server/   Helm chart -- the deployable unit
charts/zomboid-server/   Helm chart for Project Zomboid
games/valheim/           This server's config and day-to-day ops
  values.override.yaml     overrides charts/valheim-server/values.yaml
  Makefile                 deploy, logs, restart, backups, dashboards
  grafana/dashboards/      Grafana dashboard JSON
games/zomboid/           Ditto for Project Zomboid (see "Project Zomboid" below)
install/                 Run-once setup scripts, in this order
  k3s.sh                      podman + k3s + helm
  monitoring.sh               in-cluster Prometheus
  vpa.sh                      Vertical Pod Autoscaler (optional; see below)
monitoring-config/       Config the install scripts apply
  prometheus-manifests.yaml   applied with kubectl, not Helm
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
./install/vpa.sh       # optional: see "Vertical Pod Autoscaler" below before running
# Logging (Alloy, Loki, Grafana) comes from the servers-web repo's logging stack.

cd games/valheim
make push-metrics-image                   # build + push the sidecar image to the in-cluster registry
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

To restore, run the target and pick an archive from the numbered list it
shows -- it handles stopping and restarting the server:

```sh
make restore-backup
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
Grafana and Loki run in the same cluster, deployed by the servers-web repo's
logging stack. Grafana is at http://grafana.192.168.0.129.nip.io (LAN only);
the admin password comes from `make grafana-password` in servers-web. Alloy
ships every pod's logs to Loki, `games` included.

Push dashboard changes with `make dashboards`. It reads `GRAFANA_URL` and
`GRAFANA_TOKEN` (an Editor service-account token) from the game's gitignored `.env`.

## Vertical Pod Autoscaler

Optional, and separate from `monitoring.sh` on purpose: `install/vpa.sh`
clones a pinned tag of `kubernetes/autoscaler` and runs its own installer,
which sets up a **cluster-wide** admission webhook (not scoped to `games`).
Skip it entirely if you'd rather not run that.

With it installed, set `verticalPodAutoscaler.enabled: true` in
`values.override.yaml` and redeploy. Leave `updateMode: "Off"` (the chart
default) — that mode only ever writes a recommendation to the VPA object's
status; it never evicts or resizes the running pod. `Auto`/`Recreate` would,
and on a single-node box with no spare capacity to reschedule onto, a
recommendation the node can't satisfy would take the server down with no
automatic recovery. Read it with:

```sh
kubectl -n games describe vpa valheim
```

## Copying files to/from the VM

The root `Makefile` wraps `scp` for moving a file (or directory) between your
own machine and the k3s box — e.g. dropping a mod DLL on the VM before
`kubectl cp`-ing it into a pod, or grabbing a backup archive without setting
up anything game-specific. Run these from your machine, not the VM itself:
SSH only reliably works in that direction, since the VM has a stable LAN
address and a laptop usually doesn't.

```sh
make copy-to-vm   FILE=<local path>   DEST=<path on the VM>
make copy-to-host FILE=<path on VM>   DEST=<local path>
```

`VM_HOST` (`user@host`) isn't committed — set it in a local, gitignored
`.env` at the repo root, or pass it directly: `VM_HOST=user@host make
copy-to-vm ...`.

From `games/valheim/`, `make download-backups` extends `copy-to-host` to
pull every backup this box has already synced (see below) in one go.

## Mods

Off by default. To enable BepInEx, set `mods.enabled=true` in
`games/valheim/values.override.yaml`, put plugin DLLs in
`/config/bepinex/plugins` on the PVC, and redeploy.

```sh
make mods-status    # did mods load, and if not why
make approve-mods     # mark the running game build as verified, then: make restart
```

A Valheim update can arrive before a compatible BepInEx does. When that
happens the server starts **unmodded** and alerts, rather than crash-looping
— see `docs/architecture.md` for how the guard decides.

### On the admin's Windows PC

Server Devcommands only gives you the console if the mod is on your **own
client** too. `games/valheim/client-mods.ps1` handles that — copy it to the
Windows machine and run it in PowerShell:

```powershell
.\client-mods.ps1                    # install BepInEx + Server Devcommands
.\client-mods.ps1 -Action status     # what is installed, and is it active
.\client-mods.ps1 -Action disable    # launch vanilla, keep mods on disk
.\client-mods.ps1 -Action enable     # undo that
.\client-mods.ps1 -Action uninstall  # back to a clean install
```

It finds Valheim through the Steam registry keys and library folders; pass
`-GameDir "D:\...\common\Valheim"` if it can't. If Windows blocks the file,
run `powershell -ExecutionPolicy Bypass -File .\client-mods.ps1`. Close
Valheim first for anything except `status`.

Versions are pinned to the pair that were tested together; `-UseLatest`
takes whatever Thunderstore currently ships. After a Valheim update that
breaks mods, `-Action disable` gets you playing again in seconds, and
`uninstall` refuses to run if you have other mods installed unless you pass
`-Force`.

If you would rather not use the script, [r2modman](https://thunderstore.io/package/ebkr/r2modman/)
does the same job with a UI and handles updates.

## Project Zomboid

`charts/zomboid-server/` + `games/zomboid/` are built and lint clean but
**not deployed**. `games/zomboid/values.override.yaml` is sized for a
planned +32GB host RAM upgrade (Build 42 needs ~6GB just to start an empty
world) — see docs/architecture.md before deploying on the box as it exists today.

It runs `terule/pz-dedicated-server`, a thinner image than Valheim's: no
in-container update cron (`make restart` is how updates apply), and no
BepInEx-style mod fail-safe (mods have nothing to half-load, so none is
needed). Backups run from a Kubernetes CronJob instead of in-container
cron, and Discord alerts run over plain Kubernetes container hooks instead
of the image's own — both documented in docs/architecture.md. Mods go in
via `server.mods`/`server.workshopItems` in values, and persist across
restarts the same way every other setting does. There's no way to
pre-authorize an admin by Steam ID (confirmed against PZ's actual admin
model, not just this image) — `ADMIN_USERNAME`/`ADMIN_PASSWORD` is the
supported path.

## Adding another game

Copy `charts/valheim-server` (or `charts/zomboid-server` for a thinner,
hooks-free starting point) and swap the image and its env vars, then add a
`games/<name>/` with a `values.override.yaml` and a Makefile.
`game-status-metrics/` works for any game — point `GAMEDIG_GAME` at any
[gamedig](https://github.com/gamedig/node-gamedig#games-list) game id.
