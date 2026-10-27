# Off-host backup setup (Google Drive)

What the backups then do: [offsite-backups.md](offsite-backups.md).

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
4. Runs `make offsite-backup`, then installs the nightly systemd timer.

No tunnel possible: `rclone config` by hand with the
[remote setup](https://rclone.org/remote_setup/) steps, then re-run.
Last run: `journalctl -u offsite-backup --since today`. The rclone token lives in
`~/.config/rclone/rclone.conf`; keep it `600`.
For encryption at rest, wrap the remote in [crypt](https://rclone.org/crypt/)
and point `OFFSITE_BACKUP_REMOTE` at the crypt remote.
