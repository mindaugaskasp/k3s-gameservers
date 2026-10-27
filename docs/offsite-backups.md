# Off-host backups

First time on a host: [offsite-backup-setup.md](offsite-backup-setup.md).

`make offsite-backup` (repo root) runs `make sync` for every running game, then
[`rclone copy`](https://rclone.org/commands/rclone_copy/)s its backup archives flat into
`<OFFSITE_BACKUP_REMOTE>/<game>/` (root `.env`) and its world tree as one compressed
bundle into `<game>/data-bundles/`.
The archives keep their `<date>-<time>-game-day-<n>` names, the host's `archive/` tier
lands among them, and dotfiles stay off the remote. The newest archive of every
`OFFSITE_BACKUP_ARCHIVE_WINDOW_HOURS` (24) goes up, since a server that archives every few
minutes repeats a world it saves far less often; 0 uploads every archive the host holds.
**Only the bundle folders are ever pruned**, to the newest `OFFSITE_BACKUP_BUNDLES_KEPT`
(14), so pruning on the host or the pod leaves the off-host archives alone. An empty
local folder is skipped.
Uploads are capped at 20 MiB/s, about 170 Mbit/s (`OFFSITE_BACKUP_BANDWIDTH_LIMIT`,
[`--bwlimit`](https://rclone.org/docs/#bwlimit-bandwidth-spec) format) so a run
cannot saturate the host's uplink.

With `OFFSITE_BACKUP_CONFIG_PASSWORD` set (root `.env`; keep a copy in a password
manager, or the bundle is unreadable exactly when it is needed), each run also uploads
what a rebuilt machine cannot regenerate — the gitignored env files (`repo/`), the SSH
keys, git identity and rclone login (`home/`, maps onto `$HOME`) and the manually
installed packages (`system/`) — to `config-bundles/`, timestamped and kept. Unpack
the newest:

```sh
rclone lsf gdrive:k3s-gameservers-backups/config-bundles   # pick the newest
rclone copyto gdrive:k3s-gameservers-backups/config-bundles/<name> bundle.enc
openssl enc -d -aes-256-cbc -pbkdf2 -in bundle.enc | tar -xz
```
Each run pushes its result and last 40 output lines to Loki (`LOKI_URL`, root `.env`); Grafana
alerts on a failure or on no success for 26 hours.

Drive counts API calls per minute, so a run that touches many files can hit
`403 rateLimitExceeded`; one call per file is why the world goes up as a bundle and the
archives are thinned. Uploads are also paced (`OFFSITE_BACKUP_CALLS_PER_SECOND`, 4) and stop
on a quota wall rather than retrying for hours, and each step is bounded by
`OFFSITE_BACKUP_STEP_TIMEOUT` (4h) so a stall reaches Loki instead of hanging silently.
The bundle carries the world and the server's config — the player database, mods and
admin lists no archive holds — minus what the game rebuilds itself and the world a restore
set aside (`OFFSITE_BACKUP_DATA_EXCLUDES`, `cache *.replaced-*`).
Renaming archives makes the remote treat every one as new, which costs a full re-upload.

## Restore drill

`make restore-drill` (repo root; a timer runs it on the 1st and 15th) downloads each
backed-up game's newest archive and newest world bundle and verifies both open and hold
the world (`make verify-offsite-backup verify-offsite-data-bundle` per game), without
touching any live game. Results go to Loki; Grafana alerts when no drill has succeeded
for 20 days.

## Restore

Pull a copy back, then use the game's normal restore:

```sh
rclone copy gdrive:k3s-gameservers-backups/valheim games/valheim/data-backups \
  --max-depth 1 --include "*.zip"
cd games/valheim && make restore-backup
```

Reach for the world bundle when the player database, the mods or the admin lists are
what is missing; unpack it and put the files back with `make start-volume-helper`:

```sh
rclone lsf gdrive:k3s-gameservers-backups/valheim/data-bundles   # pick the newest
rclone copyto gdrive:k3s-gameservers-backups/valheim/data-bundles/<name> bundle.tar.gz
tar -xzf bundle.tar.gz -C games/valheim
```

Folders from before this layout (`<game>/data/`, `<game>/data-backups/` and
`<game>/replaced/`) are left in place; delete them on the remote when you no longer
want them.
