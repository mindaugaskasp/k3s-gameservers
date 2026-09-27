# V Rising

Runs [`trueosiris/vrising`](https://github.com/TrueOsiris/docker-vrising). The game ships a
Windows binary only, so the image runs it under Wine. Setup: [setup.md](setup.md).

## Data and config

- **Volume:** `server/` holds the steamcmd install, `persistentdata/` the world (`Saves/`),
  `Settings/` and logs, `backups/` the archives, `database/sqlite/` the exporter's player history.
- **Settings:** `ServerHostSettings.json` and `ServerGameSettings.json` in `Settings/` are copied
  from the game's defaults on the first start; every start then writes the chart's values into
  them ([image docs](https://github.com/TrueOsiris/docker-vrising#newest-modifications)).
  A key not set in values keeps whatever the file holds.
- **Difficulty:** `server.difficulty` loads one of the game's difficulty presets over
  `ServerGameSettings.json`; `gameSettings` sets any single key
  ([settings](https://github.com/StunlockStudios/vrising-dedicated-server-instructions/blob/master/1.1.x-pc/INSTRUCTIONS.md)).
- **Admins:** `admins` (Steam IDs) is written to `Settings/adminlist.txt` on every start. An admin
  enables the in-game console and runs `adminauth`.

## Updates

The image runs steamcmd on every start, so `make restart` updates the game. Clients can't join
a server older than their game, so restart after a patch. Check `make players` first.

**Saving on stop:** the server exits unsaved on SIGTERM, so the preStop hook runs
`chart/files/save-and-stop.py` first. It sends RCON's `shutdown 1`, which warns players for a
minute, then saves and exits; a stop or restart takes about a minute. RCON is left out of the
Service, so it never leaves the cluster, and its password is made by the chart on first install.

## Backups

The game keeps rotating autosaves in `Saves/v4/<world>/`. The `backup` sidecar archives the
newest one, with the world's `StartDate.json` and `SessionId.json`, into `backups/` every
`backups.intervalMinutes`, keeping `backups.maxCount`.

- `make sync` copies `persistentdata/` and the backups to `data/` and `data-backups/`.
- `make restore-backup` swaps the world folder for a backup's, keeping the old one beside it
  as `<world>.replaced-<time>/`.

## Alerts and probes

- **Alerts:** the shared start and stop hooks post to Discord when `VRISING_DISCORD_WEBHOOK` is set;
  start waits for this start's log to say `Server Setup Complete`.
- **Probes:** startup and liveness look for `VRisingServer.exe`; the first start downloads the game.

## Ports

UDP `server.gamePort` (9876) carries game traffic, UDP `server.queryPort` (9877) the Steam
query. Both must be forwarded for the server to be listed in the in-game browser.

## Monitoring

Players and play time come from the Steam query (gamedig `vrising`); the exporter also reports
the game mode, difficulty, clan size and every game setting changed from the default
([status-metrics/README.md](status-metrics/README.md)).
