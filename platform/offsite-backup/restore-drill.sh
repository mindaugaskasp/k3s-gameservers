#!/usr/bin/env bash
# Proves the off-host copies restore: downloads each backed-up game's newest archive and
# world bundle and verifies both open. Reports to Loki for the overdue alert.
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
  # Only what the game actually has off-host is verified, so a game nobody runs any more
  # is skipped instead of failing the drill.
  archive_pattern=$(make -s -C "$game_dir" print-variable NAME=BACKUP_FILE_PATTERN)
  verify_targets=""
  [ -z "$(rclone lsf "$remote/$game" --include "$archive_pattern" 2>/dev/null)" ] \
    || verify_targets+="verify-offsite-backup "
  [ -z "$(rclone lsf "$remote/$game/data-bundles" 2>/dev/null)" ] \
    || verify_targets+="verify-offsite-data-bundle "
  [ -n "$verify_targets" ] || { echo "$game: nothing on the remote, skipped"; continue; }
  if verify_output=$(make -s -C "$game_dir" $verify_targets 2>&1); then
    game_result=success
  else
    game_result=failure
    any_game_failed=1
  fi
  echo "$verify_output"
  push_line_to_loki restore-drill "$game_result" "$verify_output" "$game"
done

if [ "$any_game_failed" = 0 ]; then report_run_result restore-drill success; else report_run_result restore-drill failure; fi
exit "$any_game_failed"
