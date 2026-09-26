#!/bin/sh
# Run by `make restore-backup` in the restore helper pod, with the volume at /data and a TShock
# backup, a copy of <world>.wld, at /tmp/restore-backup. The world file is swapped; config stays.
set -e
cd /data/worlds
world=$(ls -1 *.wld 2>/dev/null | head -1)
test -n "$world"
keep=".replaced-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$keep"
mv "$world" "$keep/"
cp /tmp/restore-backup "$world"
echo "previous world kept at /root/.local/share/Terraria/Worlds/$keep"
