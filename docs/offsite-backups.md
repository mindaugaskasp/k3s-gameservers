# Off-host backups

`make offsite-backup` (repo root) runs `make sync` for every running game,
then [`rclone sync`](https://rclone.org/commands/rclone_sync/)s each
`games/<game>/data` and `data-backups` to `<OFFSITE_BACKUP_REMOTE>/<game>/` (root `.env`).
Files a run deletes or overwrites move to `<game>/replaced/<run time>/`
and each run's folder is purged after 7 days (`OFFSITE_BACKUP_KEEP_REPLACED_DAYS`).
An empty local folder is skipped, never mirrored as a wipe.
Each run pushes its result and last 40 output lines to Loki (`LOKI_URL`, root `.env`); Grafana
alerts on a failure or on no success for 13 hours.

## Setup (Google Drive)

Over SSH, connect with `-L 53682:localhost:53682` first: after login Google redirects
your browser to `127.0.0.1:53682`, and the tunnel carries that to rclone on the host. Then:

```sh
make setup-offsite-backup
```

Each step is skipped once done, so it is safe to re-run:

1. Adds `OFFSITE_BACKUP_REMOTE=gdrive:k3s-gameservers-backups` to the root `.env`.
2. Installs rclone with apt.
3. Creates the `gdrive` remote with scope `drive.file` (the token only sees
   files rclone made): open the printed `127.0.0.1:53682` link locally and log in.
4. Runs `make offsite-backup`, then installs the 6-hourly systemd timer.

No tunnel possible: `rclone config` by hand with the
[remote setup](https://rclone.org/remote_setup/) steps, then re-run.
Last run: `journalctl -u offsite-backup --since today`.

The rclone token lives in `~/.config/rclone/rclone.conf`; keep it `600`.
For encryption at rest, wrap the remote in [crypt](https://rclone.org/crypt/)
and point `OFFSITE_BACKUP_REMOTE` at the crypt remote.

## Restore

Pull a copy back, then use the game's normal restore:

```sh
rclone copy gdrive:k3s-gameservers-backups/valheim/data-backups \
  games/valheim/data-backups
cd games/valheim && make restore-backup
```

Older versions of a replaced file: `rclone lsf -R gdrive:k3s-gameservers-backups/valheim/replaced`.
