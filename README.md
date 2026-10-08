# k3s-gameservers

Game servers (Valheim, Project Zomboid, Enshrouded, Minecraft, Terraria, V Rising, RuneScape: Dragonwilds, Palworld, Satisfactory) as pods on a single-node
[k3s](https://docs.k3s.io/) cluster, with per-pod metrics for right-sizing.
Each game scales independently (`make scale-up` / `make scale-down-zero`).

## Layout

```
games/<game>/      one game: chart/, status-metrics/, grafana/, Makefile, values.override.yaml, setup.md
platform/<piece>/  the cluster (k3s, firewall, registry, monitoring, ...), each with its install.sh
game-server/       what every game shares: library chart, status-metrics core, make, systemd
docs/              setup-nodes, platform, architecture and other topics
Makefile           platform setup, dashboards, bans, off-host backups, copy-to-vm / copy-to-host (VM_HOST in .env)
```

## Setup

1. Prepare the VM: [docs/setup-nodes.md](docs/setup-nodes.md).
2. Install the platform (`make k3s`, `firewall`, `registry`, `monitoring`, `maintenance`, `dashboards`):
   ```sh
   cp platform/site.env.example platform/site.env   # then edit
   make setup
   ```
3. Set up a game (passwords, names, settings, joining, memory); read each script before running it:
   [Valheim](games/valheim/setup.md), [Project Zomboid](games/zomboid/setup.md), [Enshrouded](games/enshrouded/setup.md),
   [Minecraft](games/minecraft/setup.md), [Terraria](games/terraria/setup.md), [V Rising](games/vrising/setup.md),
   [RuneScape: Dragonwilds](games/dragonwilds/setup.md), [Palworld](games/palworld/setup.md),
   [Satisfactory](games/satisfactory/setup.md).

## Router ports

Forward these from the router to the host; each game port is a NodePort on the same number.

| Game | Port | Protocol | Carries |
| --- | --- | --- | --- |
| Valheim | 2456-2458 | UDP | game traffic and Steam query |
| Project Zomboid | 16261-16262 | UDP | game traffic (TCP 27015 is RCON: LAN only, don't forward) |
| Enshrouded | 15637 | UDP | game traffic and Steam query |
| Minecraft | 25565 | TCP | game traffic |
| Terraria | 7777 | TCP | game traffic |
| V Rising | 9876 | UDP | game traffic |
| V Rising | 9877 | UDP | Steam query, lists the server in the in-game browser |
| RuneScape: Dragonwilds | 7778 | UDP | game traffic |
| RuneScape: Dragonwilds | 8889 | UDP | world settings beacon |
| Palworld | 8211 | UDP | game traffic (TCP 8212 is the REST API: pod-only, don't forward) |
| Satisfactory | 7779 | UDP + TCP | game traffic (UDP) and the HTTPS API players join through (TCP) |
| Satisfactory | 8890 | TCP | the engine's reliable messaging |
| Website | 80, 443 | TCP | the site and its TLS certificate, through Traefik |

## Day-to-day

`make help` here or in `games/<game>/` lists every command, `make help <command>` its arguments.
Secrets and server names: gitignored `games/<game>/.env` (see `.env.example`).

- **One game at a time:** `make scale-down-zero` in one, `make scale-up` in the other.
- **Backups:** `make sync` copies the world to `data/` and `data-backups/`; [offsite-backups.md](docs/offsite-backups.md) sends them off the host.
- **Grafana:** `make dashboards` (root: all games) and `make grafana-password`.

## Docs

- [docs/setup-nodes.md](docs/setup-nodes.md): VM settings (clock, disk, IP, sizing)
- [docs/platform.md](docs/platform.md): k3s, registry, monitoring, how apps report
- [docs/overview.md](docs/overview.md): one diagram of servers, stats, Grafana and the website
- [docs/architecture.md](docs/architecture.md): games, networking, sizing
- [NEW_GAME_INSTRUCTIONS.md](NEW_GAME_INSTRUCTIONS.md): adding a game, and what each game still lacks
- [docs/metrics-flow.md](docs/metrics-flow.md): how a game's stats reach Grafana and the website
- `games/<game>/README.md`: how each game runs, beside its `setup.md`
