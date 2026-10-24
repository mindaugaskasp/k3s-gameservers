#!/bin/sh
# backup-rename.sh DIR: worlds-<date>-<time>.zip -> <date>-<time>-game-day-<n>.zip, the time
# read in BACKUP_TIMEZONE. The day comes from netTime (1800 s days, morning at 0.15), which
# the save's _main.<n>.db2 opens with: int32 version, double netTime. Unreadable: kept.

# POSIX TZ inverts a written offset, so UTC+3 is Etc/GMT-3; an IANA name passes through.
convert_timezone_to_zoneinfo() {
  case "$1" in
    UTC+*) echo "Etc/GMT-${1#UTC+}" ;;
    UTC-*) echo "Etc/GMT+${1#UTC-}" ;;
    *) echo "$1" ;;
  esac
}

backups_dir=$1
backup_zone=$(convert_timezone_to_zoneinfo "${BACKUP_TIMEZONE:-UTC}")
[ -f "/usr/share/zoneinfo/$backup_zone" ] || {
  echo "backup-rename: unknown timezone ${BACKUP_TIMEZONE:-UTC}, naming backups in UTC" >&2
  backup_zone=UTC
}

for backup_zip in "$backups_dir"/worlds-*.zip; do
  [ -f "$backup_zip" ] || continue
  newest_save_entry=$(unzip -Z1 "$backup_zip" 2>/dev/null | grep '/_main\.[0-9]*\.db2$' | sort -t. -k2 -n | tail -1)
  [ -n "$newest_save_entry" ] || { echo "backup-rename: no world save in $backup_zip" >&2; continue; }
  day=$(unzip -p "$backup_zip" "$newest_save_entry" 2>/dev/null | head -c 12 | python3 -c '
import struct, sys
header = sys.stdin.buffer.read()
net_time = struct.unpack_from("<d", header, 4)[0] if len(header) == 12 else -1
if 0 <= net_time < 1e10: print(max(0, int((net_time - 270) // 1800)))' 2>/dev/null)
  [ -n "$day" ] || { echo "backup-rename: no game time in $backup_zip" >&2; continue; }
  backup_time=$(TZ="$backup_zone" date -r "$backup_zip" +%Y%m%d-%H%M%S)
  mv -nv -- "$backup_zip" "$backups_dir/$backup_time-game-day-$day.zip"
done
