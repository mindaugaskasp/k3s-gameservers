#!/usr/bin/env bash
# Proves the off-host copies restore: downloads each backed-up game's newest archive and
# verifies it opens (make verify-offsite-backup). Reports to Loki for the overdue alert.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

remote=${OFFSITE_BACKUP_REMOTE:?set OFFSITE_BACKUP_REMOTE in the root .env, see docs/offsite-backups.md}
. platform/offsite-backup/report-to-loki.sh
any_game_failed=0

run_output_file=$(mktemp)
trap 'rm -f "$run_output_file"' EXIT
exec 3>&1 4>&2 > >(tee "$run_output_file") 2>&1
tee_pid=$!

for game_dir in games/*/; do
  game=$(basename "$game_dir")
  [ -n "$(rclone lsf "$remote/$game/data-backups" 2>/dev/null)" ] \
    || { echo "$game: nothing on the remote, skipped"; continue; }
  if output=$(make -s -C "$game_dir" verify-offsite-backup 2>&1); then
    echo "$output"
    push_line_to_loki restore-drill success "$output" "$game"
  else
    echo "$output"
    any_game_failed=1
    push_line_to_loki restore-drill failure "$output" "$game"
  fi
done

if [ "$any_game_failed" = 0 ]; then report_run_result restore-drill success; else report_run_result restore-drill failure; fi
exit "$any_game_failed"
