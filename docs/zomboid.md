# Project Zomboid

Runs [`terule/pz-dedicated-server`](https://hub.docker.com/r/terule/pz-dedicated-server).
The chart follows the variables the image's `entrypoint.sh` actually reads.
Its README disagrees with it on the port variable names.

## Names and ini

- **`server.name`** names the save, ini and db files, and can't contain
  spaces (the chart refuses). With a space, the game's own backups silently
  skip the world.
- **`server.displayName`** becomes `PublicName` in the server browser.
- **ini keys:** an initContainer sets `PublicName` and `Backups*` before the
  game reads the ini. On a new volume they only apply from the second boot,
  because the first boot has no ini yet.

## Backups

The game's own `ZipBackup` writes
`/project-zomboid-config/backups/{period,startup,version}/backup_N.zip`.
`backup_1` is the newest, and `backups.count` are kept per type.
`make restore-backup` swaps in only the world, `Server/`, `db/` and
`options.ini`.

## Updates

The image runs steamcmd on every start, so restarting is how updates apply.
The `zomboid-update` CronJob restarts the server at 05:00 UTC, but only if
RCON reports 0 players. `make scale-down-zero` suspends it; `scale-up` resumes it.

## Alerts and probes

- **Alerts:** the image has no hooks, so alerts come from Kubernetes
  [`postStart`/`preStop`](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
  hooks. `postStart` only starts a background poller, because the container
  isn't marked Running until the hook returns.
- **Probes:** `pgrep ProjectZomboid`, the same check as the image's own
  `HEALTHCHECK`.

## RCON and admins

- **RCON:** the binary is `rcon`, and each argument is one command:
  `rcon ... "servermsg \"hi\""`. `make announce MSG=...` wraps this.
- **Admins:** use `ADMIN_USERNAME` / `ADMIN_PASSWORD`. PZ can't pre-authorize a Steam ID as admin
  ([access levels](https://pzwiki.net/wiki/Server_commands)).
- **Mods:** `make add-mod WORKSHOP_ID=<id>` (Mod ID read from the Workshop page), `make mods`,
  `disable-mod`, `enable-mod`, `remove-mod`. Kept in `games/zomboid/mods.json`; `make deploy` applies.

## Memory

PZ runs on [ZGC](https://wiki.openjdk.org/display/zgc), which commits the
whole heap up front, so the container uses about `Xmx + 1GB`. Size the
memory request to match.

## Player stats

- **Online, session length, zombie kills:** from the Steam query, which reports each
  player's name, time connected and kills (as the score). Kills restart with each
  character, so the sidecar keeps a lifetime total.
- **Deaths:** from the `user` and `pvp` logs in `Logs/`.
