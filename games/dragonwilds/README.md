# RuneScape: Dragonwilds

Runs Jagex's own [`ghcr.io/runescape/rsdw-dedicated`](https://github.com/runescape/rsdw-dedicated), a
native Linux server. Setup: [setup.md](setup.md). Settings: [wiki](https://dragonwilds.runescape.wiki/w/Dedicated_Servers).

## Data and config

- **Volume:** `server/` holds the steamcmd install with `RSDragonwilds/Saved/` (world in `SaveGames/`,
  `Config/`, `Logs/`), `backups/` the archives, `database/sqlite/` the exporter's player history.
- **Settings:** the image writes `Saved/Config/LinuxServer/DedicatedServer.ini` from the chart's values on
  every start. The admin password opens the game's server management screen.
- **World:** `server.worldName` is the save's name, so a new one starts a new world.
- **Players:** at most 6, a limit of the game build.

## Updates and stopping

The image runs steamcmd on every start, so `make restart` updates the game. Check `make players` first.

**No save on stop:** the server saves every 5 minutes and when a player leaves, never on SIGTERM.
The preStop stops the server itself: the image's own stop signal never reaches it.

## Backups

The `backup` sidecar archives `SaveGames/` into `backups/` every `backups.intervalMinutes`,
keeping `backups.maxCount`.

- `make sync` copies `Saved/` and the backups to `data/` and `data-backups/`.
- `make restore-backup` swaps `SaveGames/` for a backup's, keeping the old one beside it.

## Alerts and probes

- **Alerts:** the shared start and stop hooks post to Discord when `DRAGONWILDS_DISCORD_WEBHOOK` is set;
  start waits for this start's log to say the session is `ReadyToJoin`.
- **Probes:** startup and liveness look for the server process; the first start downloads the game.

## Ports

UDP `server.gamePort` (7778) carries game traffic, UDP `server.gamePort` + 1111 (8889) is the world
settings beacon. Each NodePort is the same number as the pod's: the server advertises its own port.
The image passes the port in a form the server ignores, so the chart passes `-Port=` and `-BeaconPort=` too.

## Monitoring

gamedig has no Dragonwilds query, so the exporter reads the server log instead
([status-metrics/README.md](status-metrics/README.md)). The server logs its join password in plain
text; the platform's log shipper redacts it before Loki.
