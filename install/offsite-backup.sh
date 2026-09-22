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

if ! command -v rclone >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y rclone
fi

if ! rclone listremotes 2>/dev/null | grep -qx "$remote_name:"; then
  cat <<EOF
Creating Google Drive remote "$remote_name" (one-time login).

After you log in, Google redirects your browser to http://127.0.0.1:53682, where
rclone on this host waits for the token. From your own machine that address
only reaches this host through an SSH tunnel, so if you're on SSH without one:
  1. Ctrl+C, reconnect with: ssh -L 53682:localhost:53682 <your usual target>
  2. Re-run: make setup-offsite-backup
No tunnel possible: run 'rclone authorize "drive"' on a machine with a browser,
then paste the token into 'rclone config' here and re-run.

Open the link below in your local browser:
EOF
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
