# Architecture

## Goal

Wrap LinuxGSM (LGSM) game servers so each game/world runs as its own pod in
a local single-node k3s cluster, with per-pod metrics in Prometheus/Grafana
and a path to right-size CPU/memory per game instead of hand-tuning each
one on bare metal. Valheim (the `vhserver` instance already running on this
box) is the first candidate; more games are added by dropping a new
directory under `games/`.

## Why one Helm release per game, not one big chart

Each LGSM game is operationally independent: separate save data, separate
crash/restart behavior, separate player load, separate scaling needs. A
single chart (`charts/linuxgsm-game`) parameterized per game keeps the
Kubernetes objects (StatefulSet, PVC, Service, ServiceMonitor, VPA)
identical in shape across games, while `games/<name>/values.yaml` holds
only what's different (ports, image tag, resource sizing, LGSM instance
config). Adding a game is "add a values file", not "write new manifests."

## Why StatefulSet, not Deployment

Every LGSM instance owns a single, non-shareable world/save directory on
disk and a single running game process. There's no meaningful way to run
two replicas of the same world concurrently (unlike a stateless web app),
so `replicaCount` is always 1 and a Deployment's rolling-update semantics
(bring up a second pod before killing the first) would just fight over the
same volume. StatefulSet gives a stable pod name/identity and a
`volumeClaimTemplate` per instance, and makes the "1 world = 1 storage
volume = 1 pod" relationship explicit.

## Why VPA instead of HPA for "scaling resources"

Horizontal scaling doesn't apply to a single game world for the reason
above. "Scaling resources" here means right-sizing CPU/memory requests and
limits per game based on observed usage, which is what a
VerticalPodAutoscaler is for. It ships in **recommendation-only** mode
(`updateMode: "Off"`) by default in every `games/*/values.yaml` — the
recommender computes suggested requests (visible via
`kubectl describe vpa`) but never evicts/restarts the pod on its own,
because an uncontrolled restart mid-raid/build is exactly the kind of
surprise a game server operator doesn't want. Flip a game to
`updateMode: "Auto"` once its recommendations look sane and downtime for a
resize is acceptable.

## Container image

Rather than building a bespoke image per game, the chart defaults to
LinuxGSM's own published per-game images
(`gameservermanagers/gameserver:<shortname>`, e.g. `:vh` for Valheim —
see https://github.com/GameServerManagers/docker-gameserver). These are
built from the same install scripts as `linuxgsm.sh` on bare metal, so the
in-pod layout under `/data/lgsm/...` matches what's already on this host
(`~/lgsm/config-lgsm/vhserver/...`), and LGSM upstream keeps them updated.
`image.repository`/`image.tag` in a game's values file can override this
for a custom-built image if needed.

**Not yet validated end-to-end against a real cluster** — the exact
entrypoint/args a given `gameservermanagers/gameserver` tag expects should
be checked against its Docker Hub page before first deploy of a new game;
the chart's `command`/`args` are left as image defaults intentionally
rather than guessed at.

## Config and secrets

LGSM instance config (`instanceConfig` in values) becomes a ConfigMap
mounted at `/data/lgsm/config-lgsm/<shortname>server/<shortname>server.cfg`
— same filename/path LGSM uses on bare metal. Anything sensitive
(server password, Discord webhook URL, etc.) goes in `secrets`, which
becomes a Kubernetes Secret mounted as
`secrets-<shortname>server.cfg`, mirroring the `secrets-vhserver.cfg`
convention already used by the bare-metal instance. **Values files in this
repo never contain real passwords or the server's public IP** — those are
supplied at deploy time via `--set-string` (see `games/valheim/values.yaml`
header) or by pointing `secretRef` at a Secret created out of band.

## Monitoring

- **Infra metrics** (pod/container CPU, memory, restarts, PVC usage) come
  for free once `monitoring/kube-prometheus-values.yaml` is installed —
  cAdvisor/kubelet + kube-state-metrics, no extra code per game.
- **Game metrics** (players online, query latency, up/down) come from a
  small Node.js sidecar (`monitoring/exporter`) that queries the game's
  status port with [`gamedig`](https://github.com/gamedig/node-gamedig)
  and serves Prometheus text format on `:9101/metrics`. It runs in the
  same pod as the game server (shares the network namespace), so it always
  queries `127.0.0.1`.
- Each `charts/linuxgsm-game` release creates a `ServiceMonitor` so
  Prometheus picks the exporter up automatically; each game can ship a
  `grafana-dashboard.json` that `scripts/deploy-game.sh` loads as a
  labelled ConfigMap, which the Grafana Helm chart's dashboard sidecar
  auto-imports.

## Logs ship to the existing Grafana on the webserver VM, not a local stack

There's already a Grafana+Loki+Alloy stack running on a separate
webserver VM (192.168.0.200, `grafana.lan`). Rather than standing up a
second Loki locally (more RAM pressure on an already-tight box, and a
second place to look for logs), `games` namespace pod logs ship there:

- Exposing Loki over the LAN (an Ingress on the **webserver VM's
  cluster**, restricted via its existing `logging-lan-only` Traefik
  middleware since Loki runs with `auth_enabled: false`) is owned and
  managed on that side, not in this repo — out of scope here.
- `monitoring/alloy-logs-values.yaml` + `scripts/install-log-shipping.sh`
  — installs Grafana Alloy on **this** cluster, in logs-only mode
  (`controller.type: deployment`, not the chart's default `daemonset` —
  a single k3s node doesn't need one per node). It discovers pods via the
  Kubernetes API (no hostPath log mounts needed), keeps only the `games`
  namespace, and pushes to `http://loki.192.168.0.200.nip.io/loki/api/v1/push`
  — the nip.io form so no `/etc/hosts` edit is needed on this box.
- The Alloy config (`alloy.configMap.content` in that values file) is
  written but not yet syntax-checked against a running Alloy binary —
  verify with `kubectl -n monitoring logs -l app.kubernetes.io/name=alloy`
  after install.

The webserver VM's Loki Ingress needs to exist before
`./scripts/install-log-shipping.sh` here is useful — it curls the nip.io
URL first and warns if it's not up yet, but installs Alloy either way.

Metrics (Prometheus/Grafana dashboards, `kube-prometheus-values.yaml`)
still default to a local stack for now — worth revisiting the same way
once there's a remote-write-capable metrics backend on the webserver VM,
since that would remove the RAM-constrained local Prometheus/Grafana
entirely rather than just trimming it (see below).

## Scheduled maintenance (update/restart), replacing crontab

Bare-metal LGSM instances typically run their own maintenance crontab —
this host's `vhserver` had:

```
0 1 * * *  vhserver update
0 2 * * *  vhserver restart
0 3 * * 0  vhserver update-lgsm
*/5 * * * *  vhserver monitor
@reboot    vhserver start
```

In the pod, `@reboot` and `monitor` (crash detection) are subsumed by k8s
itself: the StatefulSet always brings the pod back up, and an optional
`livenessProbe` (see `games/valheim/values.yaml` — a `pgrep` check) gets
kubelet to restart the container the same way `monitor` restarts the
process, without needing a player-count check (a crashed server isn't
serving anyone regardless of how many were connected).

`update` and `restart` are different: firing them mid-session boots
whoever's online. `charts/linuxgsm-game`'s `maintenance.*Schedule` values
create CronJobs (RBAC-scoped to `exec` into exactly this release's pod,
nothing else) that `kubectl exec` into the `metrics-exporter` container,
read `lgsm_game_players` off its `/metrics`, and only proceed with
`kubectl exec ... ./<shortname>server <action>` in the `gameserver`
container if the count is exactly `0`; otherwise that run is skipped and
the next scheduled run tries again (`maintenance.waitForEmptyMinutes` can
make a single run retry-and-wait instead, off by default). `update-lgsm`
(LGSM's own self-update) is a plain unguarded CronJob since it only
touches `lgsm/modules`, never the running game process.

## Resource constraints on this box

`vhserver` (Ubuntu 24.04, TrueNAS SCALE VM) currently has 7.7GB RAM and 4
vCPUs (host is a single i7-9700K, 8 real threads, shared with TrueNAS
itself). `kube-prometheus-stack` (Prometheus + Grafana +
kube-state-metrics + node-exporter) plus k3s itself plus one or more game
pods may still not comfortably fit; the values files here
(`monitoring/kube-prometheus-values.yaml`) are trimmed down (Alertmanager
disabled, 3-day retention, low resource requests/limits), but treat this
as a real constraint before installing the monitoring stack.

## VM's vCPU topology was misconfigured (128 apparent cores, 4 real)

TrueNAS's VM CPU config had Sockets=4, Cores=4, Threads=8 (multiplies to
128), not the intended 4 vCPUs -- the "Virtual CPUs" field there is a
socket-count multiplier, not a total. The guest saw `nproc`=128 against 4
real vCPUs, which inflated Valheim's idle CPU usage to ~3.7 cores (Unity's
job system sizing its thread pool for the phantom core count). Fixed to
Sockets=1, Cores=4, Threads=1 (needs a VM restart); idle usage dropped to
~130m afterward, matching community baselines.

## NodePort range widened to include 2456-2458

k8s's default NodePort range (30000-32767) doesn't cover Valheim's
2456-2458, which the router already forwards from bare-metal days. Fixed
via `/etc/rancher/k3s/config.yaml`: `kube-apiserver-arg:
["service-node-port-range=2456-32767"]`, then `systemctl restart k3s`
(control-plane only -- running pods are untouched).

## VM disk was resized once; k3s TLS certs came up invalid afterward

The VM's root disk was originally a 15GB zvol, fully partitioned. Growing
a Valheim install (~2GB) alongside the existing bare-metal copy hit
`DiskPressure` and then `Not enough disk space to download server files`.
Fix: grow the zvol on the TrueNAS host, restart the VM, then from inside
it `growpart /dev/sda 3` -> `pvresize /dev/sda3` -> `lvextend -l +100%FREE
-r /dev/ubuntu-vg/ubuntu-lv`.

That VM restart surfaced a second, unrelated problem: k3s failed with
`x509: certificate ... is not yet valid`. Root cause: the VM's RTC was
stale/wrong right after power-on, and `k3s.service` (which only waited on
`network-online.target`) started and minted its serving cert before NTP
corrected the clock. k3s persists that cert in its embedded datastore, so
even once the clock was fixed, every restart just reloaded the same
bad-`notBefore` cert -- deleting the local cert file on disk didn't help,
it just got regenerated from the same stored (bad) value. Fix required
finding and deleting the `kube-system/k3s-serving` row directly from the
sqlite-backed datastore (`/var/lib/rancher/k3s/server/db/state.db`, table
`kine`) with k3s stopped, then restarting.

`scripts/install-k3s.sh` now makes `k3s.service` wait on
`time-sync.target` (via a systemd drop-in + enabling
`systemd-time-wait-sync.service`) so this can't recur on a future boot --
the underlying `network-online.target` dependency k3s ships with does not
imply the clock has actually been verified synced.

## Adding a new game

1. `mkdir games/<name>`
2. Copy `games/valheim/values.yaml` as a starting point; set
   `game.shortname`/`game.name`, `image.tag`, `ports`,
   `metricsExporter.gamediggame`/`queryPort`, and `instanceConfig`.
3. Optionally add `games/<name>/grafana-dashboard.json`.
4. `./scripts/deploy-game.sh <name> [--set-string secrets.xxx=...]`
