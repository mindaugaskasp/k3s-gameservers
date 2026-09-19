#!/bin/sh
# backup-rename.sh DIR: worlds-<date>-<time>.zip -> <date>-<time>-game-day-<n>.zip.
# The day comes from netTime (1800 s days, morning at 0.15), which the save's
# _main.<n>.db2 opens with: int32 version, double netTime. Unreadable: kept.
dir=$1
for z in "$dir"/worlds-*.zip; do
  [ -f "$z" ] || continue
  e=$(unzip -Z1 "$z" 2>/dev/null | grep '/_main\.[0-9]*\.db2$' | sort -t. -k2 -n | tail -1)
  [ -n "$e" ] || { echo "backup-rename: no world save in $z" >&2; continue; }
  day=$(unzip -p "$z" "$e" 2>/dev/null | head -c 12 | python3 -c '
import struct, sys
b = sys.stdin.buffer.read()
t = struct.unpack_from("<d", b, 4)[0] if len(b) == 12 else -1
if 0 <= t < 1e10: print(max(0, int((t - 270) // 1800)))' 2>/dev/null)
  [ -n "$day" ] || { echo "backup-rename: no game time in $z" >&2; continue; }
  stamp=${z##*/worlds-}; new="$dir/${stamp%.zip}-game-day-$day.zip"
  mv -nv -- "$z" "$new"
done
