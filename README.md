# k3s-gameservers

Game servers (Valheim, Project Zomboid) as pods on a single-node
[k3s](https://docs.k3s.io/) cluster, with per-pod metrics for right-sizing.
Each game scales independently (`make scale-up` / `make scale-down-zero`).

## Layout

```
charts/<game>-server/      Helm chart per game
games/<game>/              values.override.yaml, Makefile, Grafana dashboards
install/                   k3s.sh, registry.sh, monitoring.sh, vpa.sh (optional)
registry/, monitoring/     platform: image registry; Prometheus, Loki, Alloy, Grafana
game-status-metrics/       player/status exporter sidecar (gamedig)
docs/                      setup-nodes, platform, architecture, valheim, zomboid
Makefile                   copy-to-vm / copy-to-host (run from your machine)
```

## Setup

1. Prepare the VM: [docs/setup-nodes.md](docs/setup-nodes.md).
2. Install the cluster:
   ```sh
   ./install/k3s.sh && ./install/registry.sh
   cp monitoring/site.env.example monitoring/site.env   # then edit
   ./install/monitoring.sh
   ```
3. Deploy a game (read each script before running it):
   ```sh
   cd games/valheim
   make push-metrics-image
   VALHEIM_SERVER_PASSWORD=... make deploy
   ```

## Day-to-day

Run `make help` in `games/<game>/` for every target: logs, players,
restart, scale-up / scale-down-zero, backups, sync, restore-backup, and
dashboards. Secrets come from env vars or a gitignored `games/<game>/.env`.

- **One game at a time:** `make scale-down-zero` in one, `make scale-up` in the other.
- **Backups:** the world lives on the PVC. `make sync` copies it to the
  gitignored `data/` and `data-backups/`.
- **Grafana:** `make dashboards` ships dashboards; `make grafana-password` (root).
- **Root `Makefile`:** copy-to-vm / copy-to-host; set `VM_HOST` in the root `.env`.

## Docs

- [docs/setup-nodes.md](docs/setup-nodes.md): TrueNAS VM settings (UTC
  clock, disk, stable IP, CPU, RAM)
- [docs/platform.md](docs/platform.md): k3s, registry, monitoring, how apps report
- [docs/architecture.md](docs/architecture.md): games, networking, sizing
- [docs/valheim.md](docs/valheim.md) and [docs/zomboid.md](docs/zomboid.md):
  per-game notes

## Adding a game

Copy a chart under `charts/`, swap in the new image and its env vars, and
add `games/<name>/`. The sidecar supports any
[gamedig game id](https://github.com/gamedig/node-gamedig/blob/master/GAMES_LIST.md).
