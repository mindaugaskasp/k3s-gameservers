# Satisfactory

Runs [`wolveix/satisfactory-server`](https://github.com/wolveix/satisfactory-server).

## Data and config

- **PVC** is mounted at `/config`: the steamcmd install in `gamefiles/`, the saves,
  blueprints and server settings in `saved/`, backup archives in `backups/`.
- **First boot** downloads the game; the server is unreachable until it finishes,
  and an update needs up to twice the game size on disk.
- **The server starts unclaimed.** The first player to connect claims it and sets
  its name, admin password and session in game; the chart holds no passwords.
- **Tuning** comes from values, and `games/satisfactory/.env` overrides the common
  ones (slots, autosaves, tick rate) without editing them.

## Updates and backups

- **Updates:** steamcmd checks on every container start (`updates.onBoot`);
  there is no in-place update, so updating a running server is `make restart`.
  Check `make players` first: a restart disconnects everyone.
- **Backups:** the image only copies the saves into `backups/` on boot, so the
  `backup` sidecar archives `saved/` every `backups.intervalMinutes`, keeping
  `backups.maxCount`. `make restore-backup` swaps one back in.
- **Saving:** autosaves carry the world (`AUTOSAVENUM` keeps that many); upstream
  documents no save on stop, so turn on Auto-Save on Player Disconnect in the
  server settings and the last session is never older than one autosave.

## Alerts and probes

- **Alerts:** start and stop come from Kubernetes `postStart`/`preStop` hooks,
  like every other game here; the image posts nothing itself.
- **Probes:** startup waits for the HTTPS API's unauthenticated health check;
  liveness watches the `FactoryServer-Linux` process.

## Ports and admin

- **Three NodePorts**, all player-facing (`values.override.yaml`): the game over
  UDP, the HTTPS API players join through over TCP on the same port, and the
  engine's reliable messaging over TCP. The API gives admin commands only to a
  claimed login, so exposing it is the game's own design.
- **Player stats:** the sidecar asks gamedig's lightweight query and the HTTPS
  API. The API counts players without naming them, so the count is real but the
  per-player stats stay empty; with a client-protection password set, give the
  exporter `SATISFACTORY_API_TOKEN` or the count drops to zero.
