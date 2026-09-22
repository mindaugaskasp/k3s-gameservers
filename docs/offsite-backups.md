# Off-host backups

`make offsite-backup` (repo root) runs `make sync` for every running game,
then [`rclone sync`](https://rclone.org/commands/rclone_sync/)s each
`games/<game>/data` and `data-backups` to `OFFSITE_BACKUP_REMOTE` (root `.env`).
Files a run deletes or overwrites move to `replaced/<run time>/` on the remote
and each run's folder is purged after 7 days (`OFFSITE_BACKUP_KEEP_REPLACED_DAYS`).
An empty local folder is skipped, never mirrored as a wipe.

## Setup (Google Drive)

1. Install rclone on the k3s host: `sudo apt-get install -y rclone`
   or the [official script](https://rclone.org/install/).
2. Create the remote: `rclone config` -> `n` -> name `gdrive` -> `drive`.
   - **Scope:** `drive.file`, so the token only sees files rclone made,
     not the rest of the Drive.
   - **Headless host:** answer `n` to "use web browser", run the printed
     `rclone authorize "drive" ...` on a machine with a browser and paste
     the token back ([remote setup](https://rclone.org/remote_setup/)).
3. Set `OFFSITE_BACKUP_REMOTE=gdrive:k3s-gameservers-backups` in the root
   `.env` (see `.env.example`), then check it: `make offsite-backup`.
4. Every 6 hours from then on: `make install-offsite-backup-timer`.
   Last run: `journalctl -u offsite-backup --since today`.

The rclone token lives in `~/.config/rclone/rclone.conf`; keep it `600`.
For encryption at rest, wrap the remote in [crypt](https://rclone.org/crypt/)
and point `OFFSITE_BACKUP_REMOTE` at the crypt remote.

## Restore

Pull a copy back, then use the game's normal restore:

```sh
rclone copy gdrive:k3s-gameservers-backups/games/valheim/data-backups \
  games/valheim/data-backups
cd games/valheim && make restore-backup
```

Older versions of a replaced file: `rclone lsf -R gdrive:k3s-gameservers-backups/replaced`.
