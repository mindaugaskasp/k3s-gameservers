# Enshrouded

Runs [`mornedhels/enshrouded-server`](https://github.com/mornedhels/enshrouded-server).
The game ships a Windows binary only, so the image runs it under Proton
(`stable-wine` is the Wine build).

## Data and config

- **PVC** is mounted at `/opt/enshrouded`: the steamcmd install in `server/`,
  plus `savegame/`, `logs/` and `backups/`.
- **`enshrouded_server.json`** (in `server/`) is rewritten from the `SERVER_*`
  env vars on every boot, so edit values, not the file.
- **First boot** downloads the game; the server is unreachable until it
  finishes, and an update needs up to twice the game size on disk.
- **Settings** come from values, and `games/enshrouded/.env` overrides the
  common ones (name, slots, chat, difficulty) without editing them.

## Difficulty

`gameSettings` keys become `SERVER_GS_<KEY>`; individual keys apply only with
`PRESET: Custom`
([list](https://github.com/mornedhels/enshrouded-server/blob/main/docs/SERVER_DIFFICULTY.md)).

## Roles instead of a password

Enshrouded has no single server password. Each role has its own, and the
password a player joins with picks their role
([roles](https://github.com/mornedhels/enshrouded-server/blob/main/docs/SERVER_ROLES.md)).
`roles` in values holds the permissions, `secrets.rolePasswords` the
passwords, keyed by each role's `secretKey`.

## Updates, restarts and backups

All three are the image's own crons, not Kubernetes CronJobs:

- **Updates** (`updates.cron`) restart the game process in place, keeping the
  pod. With `updates.ifIdle`, an update is skipped while players are on.
- **Backups** (`backups.cron`) zip the newest save into `backups/`;
  `backups.maxCount` are kept. `make restore-backup` unpacks one back into
  `savegame/`.
- **`restart.cron`** is upstream work-in-progress and off by default.

## Alerts and probes

- **Alerts:** start and stop come from Kubernetes
  [`postStart`/`preStop`](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
  hooks, updates from the image's `UPDATE_POST_HOOK`. `postStart` only starts
  a background poller, because the container isn't Running until it returns.
- **Probes:** startup waits for `enshrouded_server.exe`; liveness watches
  `supervisord`, because the updater stops the game process in place.

## Ports and admin

- **One UDP port** (`server.queryPort`, default 15637) carries both game
  traffic and Steam queries.
- **No RCON:** the image is driven with `supervisorctl`
  (`make force-update`, `make backup-now`); in-game moderation needs the
  `canKickBan` role.
- **Player stats:** the query reports no names, so the sidecar reads joins, leaves
  and base counts from `logs/enshrouded_server.log`. No log records deaths or kills.
