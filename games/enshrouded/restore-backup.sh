#!/bin/sh
# Run by `make restore-backup` in the restore helper pod, with the volume at /data and the backup
# at /tmp/restore.zip. The zip holds the newest save file plus its index, both restored into
# savegame/. The game install and backups/ are left alone.
set -e
cd /data
keep=".replaced-$(date +%Y%m%d-%H%M%S)"
[ -d savegame ] && mv savegame "$keep"
mkdir -p savegame; unzip -q -o /tmp/restore.zip -d savegame
chown -R 1000:1000 savegame  # the chart's PUID
echo "previous world kept at /opt/enshrouded/$keep"
