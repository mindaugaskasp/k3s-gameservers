#!/bin/sh
# Run by `make restore-backup` in the restore helper pod, with the volume at /data and the backup
# at /tmp/restore.zip. The zip holds Saves/Multiplayer/<name>, Server/, db/ and options.ini
# relative to /project-zomboid-config; only those are swapped, so Logs/ and backups/ stay put.
set -e
cd /data/config
name=$(unzip -p /tmp/restore.zip readme.txt | sed -n "s/^ServerName: *//p" | tr -d "\r")
test -n "$name"
keep=".replaced-$(date +%Y%m%d-%H%M%S)"
for p in "Saves/Multiplayer/$name" Server db options.ini; do
  [ -e "$p" ] && mkdir -p "$keep/$(dirname "$p")" && mv "$p" "$keep/$p"; true
done
unzip -q -o /tmp/restore.zip -x readme.txt
echo "previous world kept at /project-zomboid-config/$keep"
