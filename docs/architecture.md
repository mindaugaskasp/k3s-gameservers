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

## Resource constraints on this box

The original host (`vhserver`/Ubuntu 24.04) has **~5.7GB RAM total**, and
was observed with under 200MB free while running the bare-metal Valheim
server plus its own tooling. `kube-prometheus-stack` (Prometheus +
Grafana + kube-state-metrics + node-exporter) plus k3s itself plus one or
more game pods will not comfortably fit in what's left. The values files
here (`monitoring/kube-prometheus-values.yaml`) are trimmed down
(Alertmanager disabled, 3-day retention, low resource requests/limits),
but this is still worth treating as a real constraint: either free up RAM
on this box before installing the monitoring stack, or plan to run k3s on
different/bigger hardware and treat this host as just a data source.

## Adding a new game

1. `mkdir games/<name>`
2. Copy `games/valheim/values.yaml` as a starting point; set
   `game.shortname`/`game.name`, `image.tag`, `ports`,
   `metricsExporter.gamediggame`/`queryPort`, and `instanceConfig`.
3. Optionally add `games/<name>/grafana-dashboard.json`.
4. `./scripts/deploy-game.sh <name> [--set-string secrets.xxx=...]`
