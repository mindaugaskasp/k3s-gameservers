#!/bin/sh
# Run by `make restore-backup` in the restore helper pod, with the volume at /data and a backup
# tar.gz at /tmp/restore-backup, which holds SaveGames/. That folder is swapped.
set -e
cd /data/server/RSDragonwilds/Saved
keep="SaveGames.replaced-$(date +%Y%m%d-%H%M%S)"
[ -d SaveGames ] && mv SaveGames "$keep"
tar -xzf /tmp/restore-backup
chown -R 1000:1000 SaveGames
echo "previous saves kept at /home/steam/rsdw-dedicated/RSDragonwilds/Saved/$keep"
