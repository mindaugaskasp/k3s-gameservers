# k3s-gameservers

Game servers (Valheim, Project Zomboid, Enshrouded) as pods on a single-node
[k3s](https://docs.k3s.io/) cluster, with per-pod metrics for right-sizing.
Each game scales independently (`make scale-up` / `make scale-down-zero`).

## Layout

```
charts/<game>-server/      Helm chart per game
games/<game>/              values.override.yaml, Makefile, Grafana dashboards, status-metrics/
platform/<piece>/          the cluster: k3s, firewall, registry, monitoring, crowdsec, maintenance,
                           offsite-backup, vpa; each with its install.sh, see docs/platform.md
game-server/               what every game shares: library chart, status-metrics core, make, systemd
docs/                      setup-nodes, platform, architecture, game-setup, per-game
Makefile                   platform setup, dashboards, bans, off-host backups, copy-to-vm / copy-to-host
```

## Setup

1. Prepare the VM: [docs/setup-nodes.md](docs/setup-nodes.md).
2. Install k3s, the registry, monitoring and every game's dashboards
   (steps: `make k3s`, `firewall`, `registry`, `monitoring`, `maintenance`, `dashboards`):
   ```sh
   cp platform/site.env.example platform/site.env   # then edit
   make setup
   ```
3. Set up a game, step by step (passwords, settings, joining, mods, memory):
   [Valheim](games/valheim/setup.md), [Project Zomboid](games/zomboid/setup.md),
   [Enshrouded](games/enshrouded/setup.md). Read each script before running it.

## Day-to-day

Run `make help` here or in `games/<game>/` for every command (logs, players, restart,
backups, sync, restore-backup, dashboards), and `make help <command>` for its arguments.
Secrets: gitignored `games/<game>/.env` (see `.env.example`).

- **One game at a time:** `make scale-down-zero` in one, `make scale-up` in the other.
- **Backups:** the world lives on the PVC. `make sync` copies it to `data/` and
  `data-backups/`; [offsite-backups.md](docs/offsite-backups.md) pushes them off the host.
- **Grafana:** `make dashboards` (root: all games) and `make grafana-password`.
- **Root `Makefile`:** copy-to-vm / copy-to-host; set `VM_HOST` in the root `.env`.

## Docs

- [docs/setup-nodes.md](docs/setup-nodes.md): VM settings (clock, disk, IP, sizing)
- [docs/platform.md](docs/platform.md): k3s, registry, monitoring, how apps report
- [docs/architecture.md](docs/architecture.md): games, networking, sizing
- [docs/game-setup.md](docs/game-setup.md): checklist for adding a game
- [docs/valheim.md](docs/valheim.md), [docs/zomboid.md](docs/zomboid.md) and
  [docs/enshrouded.md](docs/enshrouded.md): per-game notes

## Adding a game

Follow [docs/game-setup.md](docs/game-setup.md). The sidecar supports any
[gamedig game id](https://github.com/gamedig/node-gamedig/blob/master/GAMES_LIST.md).
