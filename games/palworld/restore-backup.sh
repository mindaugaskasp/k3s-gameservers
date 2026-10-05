#!/bin/sh
# Run by `make restore-backup` in the restore helper pod, with the volume at /data and the backup
# at /tmp/restore-backup. The tar holds Saved/ (world, settings and logs), restored into Pal/.
# The game install and backups/ are left alone.
set -e
mkdir -p /data/Pal
cd /data/Pal
keep=".replaced-$(date +%Y%m%d-%H%M%S)"
[ -d Saved ] && mv Saved "$keep"
tar xzf /tmp/restore-backup
chown -R 1000:1000 Saved  # the chart's PUID
echo "previous world kept at /palworld/Pal/$keep"
