#!/bin/sh
# Run by `make restore-backup` in the restore helper pod, with the volume at /data and the
# mc-backup tar at /tmp/restore-backup. Only the world folders are swapped; config stays.
set -e
cd /data/minecraft
rm -rf .restore-tmp; mkdir -p .restore-tmp
tar -xzf /tmp/restore-backup -C .restore-tmp
test -f .restore-tmp/world/level.dat
keep=".replaced-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$keep"
for world in world world_nether world_the_end; do
  [ -d "$world" ] && mv "$world" "$keep/"
  [ -d ".restore-tmp/$world" ] && mv ".restore-tmp/$world" .
done
rm -rf .restore-tmp
chown -R 1000:1000 world*
echo "previous world kept at /data/$keep"
