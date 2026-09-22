#!/usr/bin/env bash
# Off-host backups end to end, safe to re-run: installs rclone, logs in to Google Drive once,
# runs a backup and installs the 6-hourly timer. See docs/offsite-backups.md.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! grep -q '^OFFSITE_BACKUP_REMOTE=' .env 2>/dev/null; then
  [ -s .env ] && [ -n "$(tail -c1 .env)" ] && echo >> .env
  echo "OFFSITE_BACKUP_REMOTE=gdrive:k3s-gameservers-backups" >> .env
fi
remote=$(sed -n 's/^OFFSITE_BACKUP_REMOTE=//p' .env | tail -1)
remote_name=${remote%%:*}

needs_login=false
command -v rclone >/dev/null && rclone listremotes 2>/dev/null | grep -qx "$remote_name:" || needs_login=true

if $needs_login; then
  cat <<EOF
One-time Google Drive login for rclone remote "$remote_name".

After you log in, Google redirects your browser to http://127.0.0.1:53682, where
rclone on this host waits for the token. From your own machine that address only
reaches this host through an SSH tunnel. Before continuing, open a SECOND terminal
on your machine and leave this running there:

  ssh -N -L 53682:localhost:53682 $(id -un)@$(hostname -I | awk '{print $1}')

  (-N forwards the port only and seems to hang; that is expected.
   PuTTY: Connection > SSH > Tunnels, source 53682, destination localhost:53682.)

No tunnel possible: Ctrl+C, run 'rclone authorize "drive"' on a machine with a
browser, paste the token into 'rclone config' here, then re-run.
EOF
  [ -t 0 ] && read -r -p "Press Enter once the tunnel is open... "
fi

if ! command -v rclone >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y rclone
fi

if $needs_login; then
  echo "Open the link below in your local browser and log in:"
  rclone config create "$remote_name" drive scope=drive.file
fi
rclone lsd "$remote_name:" >/dev/null \
  || { echo "Can't reach $remote_name:, log in again: rclone config reconnect $remote_name:" >&2; exit 1; }

make -s offsite-backup

sed -e "s|__REPO__|$PWD|g" -e "s|__USER__|$(id -un)|g" -e "s|__HOME__|$HOME|g" \
  offsite-backup/systemd/offsite-backup.service | sudo tee /etc/systemd/system/offsite-backup.service >/dev/null
sudo cp offsite-backup/systemd/offsite-backup.timer /etc/systemd/system/offsite-backup.timer
sudo systemctl daemon-reload
sudo systemctl enable --now offsite-backup.timer
systemctl list-timers offsite-backup.timer --no-pager
