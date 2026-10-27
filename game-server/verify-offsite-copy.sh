#!/usr/bin/env bash
# Downloads the newest file an off-host folder holds and verifies it opens, so a restore
# is proven to be there rather than assumed.
# Usage: verify-offsite-copy.sh <rclone remote> <folder in it> <name to report it under>
# LIST_COMMAND='unzip -l'   how to open the file, tar -tzf by default
# FILE_PATTERN='*.zip'      which files count, all of them by default
# REQUIRED_ENTRY=path       a path the file has to hold
set -euo pipefail
remote=${1:?set OFFSITE_BACKUP_REMOTE in the root .env, see docs/offsite-backups.md}
remote_folder="$remote/$2" reported_name=$3
list_command=${LIST_COMMAND:-tar -tzf}
file_pattern=${FILE_PATTERN:-*}
required_entry=${REQUIRED_ENTRY:-}

# lsf --format tp prints "time;path", so a plain sort ends newest-last.
newest_file=$(rclone lsf "$remote_folder" --files-only --format tp 2>/dev/null \
  | sort | cut -d';' -f2- | while read -r remote_file; do
      case "$remote_file" in $file_pattern) echo "$remote_file";; esac
    done | tail -1)
[ -n "$newest_file" ] || { echo "$reported_name: nothing matching '$file_pattern' on the remote" >&2; exit 1; }
download_folder=$(mktemp -d)
trap 'rm -rf "$download_folder"' EXIT
rclone copyto "$remote_folder/$newest_file" "$download_folder/$newest_file"
$list_command "$download_folder/$newest_file" > "$download_folder/entries" \
  || { echo "$reported_name: $newest_file does not open" >&2; exit 1; }
[ -z "$required_entry" ] || grep -q -- "$required_entry" "$download_folder/entries" \
  || { echo "$reported_name: $newest_file has no $required_entry in it" >&2; exit 1; }
echo "$reported_name: $newest_file downloads and opens"
