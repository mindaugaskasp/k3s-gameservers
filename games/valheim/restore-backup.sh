#!/bin/sh
# Run by `make restore-backup` in the restore helper pod, with the volume at /data and the
# backup at /tmp/restore.zip. Archive paths are config/worlds_local/..., so it unpacks at the root.
set -e
cd /data
rm -rf .restore-tmp; mkdir -p .restore-tmp
unzip -q -o /tmp/restore.zip -d .restore-tmp
test -d .restore-tmp/config/worlds_local
ts=$(date +%Y%m%d-%H%M%S)
if [ -d config/worlds_local ]; then mv config/worlds_local "config/worlds_local.replaced-$ts"; fi
mv .restore-tmp/config/worlds_local config/worlds_local
rm -rf .restore-tmp
echo "previous world kept at config/worlds_local.replaced-$ts"
