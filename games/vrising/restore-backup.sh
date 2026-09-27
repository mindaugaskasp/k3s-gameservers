#!/bin/sh
# Run by `make restore-backup` in the restore helper pod, with the volume at /data and a backup tar
# at /tmp/restore-backup, which holds v<version>/<world>/ with one autosave. That world folder is swapped.
set -e
cd /data/persistentdata/Saves
world=$(dirname "$(tar -tf /tmp/restore-backup | grep '\.save\.gz$' | head -1)")
keep="$world.replaced-$(date +%Y%m%d-%H%M%S)"
[ -d "$world" ] && mv "$world" "$keep"
tar -xf /tmp/restore-backup
echo "previous world kept at /mnt/vrising/persistentdata/Saves/$keep"
