#!/bin/sh
# Run by `make restore-backup` in the restore helper pod, with the volume at /data and the backup
# at /tmp/restore-backup. The tar holds saved/ (saves, blueprints and server settings); that
# folder is swapped, and the game install and backups/ are left alone.
set -e
cd /data
keep="saved.replaced-$(date +%Y%m%d-%H%M%S)"
[ -d saved ] && mv saved "$keep"
tar xzf /tmp/restore-backup
chown -R 1000:1000 saved  # the chart's PUID
echo "previous saves kept at /config/$keep"
