#!/usr/bin/env bash
# Pulls each running game's world and backups (make sync), then copies one backup archive
# per window flat into OFFSITE_BACKUP_REMOTE/<game>/ and the world tree as one compressed
# bundle in <game>/data-bundles/. Only the bundle folders are pruned, to the newest few;
# the archives are never deleted. Config files go up as an encrypted bundle too; see
# docs/offsite-backups.md.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

remote=${OFFSITE_BACKUP_REMOTE:?set OFFSITE_BACKUP_REMOTE in the root .env, see docs/offsite-backups.md}
# rclone --bwlimit format. A full-speed upload can starve game traffic and the host's NIC.
upload_rate_limit=${OFFSITE_BACKUP_BANDWIDTH_LIMIT:-20M}
# Drive answers 403 rateLimitExceeded once a run makes too many API calls a minute, which
# renaming many archives does. These pace the calls, fail fast on a quota wall instead of
# retrying for hours, and bound a stalled step so its failure still reaches Loki.
drive_calls_per_second=${OFFSITE_BACKUP_CALLS_PER_SECOND:-4}
upload_step_timeout=${OFFSITE_BACKUP_STEP_TIMEOUT:-4h}
# Left out of the world bundle: what the game rebuilds by itself, and the world a restore
# set aside. The world and the server's config go up; the archives carry the world too,
# but only data/ has the player database, the mods and the admin lists.
read -r -a data_tree_excludes <<< "${OFFSITE_BACKUP_DATA_EXCLUDES:-cache *.replaced-*}"
bundle_exclude_flags=()
for excluded in "${data_tree_excludes[@]}"; do bundle_exclude_flags+=(--exclude "data/$excluded"); done
# One archive per this many whole hours goes off-host; 0 uploads every archive the host
# holds. A server that archives every few minutes repeats a world it saves far less
# often, and every extra file is another Drive call.
archive_window_hours=${OFFSITE_BACKUP_ARCHIVE_WINDOW_HOURS:-24}
# How many world bundles and config bundles to keep on the remote, newest first.
bundles_kept=${OFFSITE_BACKUP_BUNDLES_KEPT:-14}
rclone_pacing_flags=(--tpslimit "$drive_calls_per_second" --transfers 2 --checkers 4
  --drive-pacer-min-sleep 100ms --drive-stop-on-upload-limit)
run_started_at=$(date -u +%Y%m%d-%H%M%S)

# One upload step. copy never deletes on the remote, and timeout bounds a stall so the
# step still reports its failure instead of hanging the run.
upload_to_remote() {
  local source=$1 destination=$2; shift 2
  timeout "$upload_step_timeout" rclone copy "$source" "$destination" \
    --bwlimit "$upload_rate_limit" "${rclone_pacing_flags[@]}" "$@"
}
any_step_failed=0

# The newest archive in each window, as names rclone --files-from reads. The server's own
# retention decides what is here; this only thins what a run uploads.
newest_archive_per_window() {
  local archive_folder=$1 archive_pattern=$2
  [ "$archive_window_hours" -gt 0 ] \
    || { find "$archive_folder" -maxdepth 1 -type f -name "$archive_pattern" -printf "%P\n"; return 0; }
  find "$archive_folder" -maxdepth 1 -type f -name "$archive_pattern" -printf "%T@ %P\n" | sort -rn \
    | awk -v window_seconds=$((archive_window_hours * 3600)) \
        '{ window = int($1 / window_seconds); sub(/^[^ ]+ /, ""); if (!uploaded[window]++) print }'
}

# The world tree as one file, so a tree of thousands of small world chunks costs one
# upload instead of one Drive call per file.
upload_data_bundle() {
  local game=$1 game_dir=$2 bundle_folder upload_result=1
  bundle_folder=$(mktemp -d)
  if tar -czf "$bundle_folder/$game-data-$run_started_at.tar.gz" \
    -C "$game_dir" "${bundle_exclude_flags[@]}" data; then
    upload_to_remote "$bundle_folder" "$remote/$game/data-bundles" && upload_result=0
  fi
  rm -rf "$bundle_folder"
  return "$upload_result"
}

# Keeps the newest bundles in one folder this script writes, and nothing else on the remote.
# lsf --format tp prints "time;path", so a plain sort ends newest-last.
prune_remote_bundles() {
  local bundle_folder=$1 outdated_bundles
  [ "$bundles_kept" -gt 0 ] || return 0
  outdated_bundles=$(rclone lsf "$bundle_folder" --files-only --format tp 2>/dev/null \
    | sort | cut -d';' -f2- | head -n "-$bundles_kept" || true)
  [ -n "$outdated_bundles" ] || return 0
  # A delete that fails is said out loud but never fails the run: the backup itself is up.
  while read -r outdated_bundle; do
    if rclone deletefile "$bundle_folder/$outdated_bundle"; then
      echo "Deleted $bundle_folder/$outdated_bundle"
    else
      echo "could not delete $bundle_folder/$outdated_bundle" >&2
    fi
  done <<< "$outdated_bundles"
}

# Kept to send with the run's result, so Grafana shows what a failed run printed.
run_output_file=$(mktemp)
trap 'rm -f "$run_output_file"' EXIT
exec 3>&1 4>&2 > >(tee "$run_output_file") 2>&1
tee_pid=$!

# The alerts in platform/monitoring/config/alerting.yaml read what these report.
. platform/offsite-backup/report-to-loki.sh

report_game_result() {
  local game=$1 uploaded_folders=${2% } failed_folders=${3% } remote_size
  remote_size=$(rclone size --json "$remote/$game" --exclude "replaced/**" 2>/dev/null \
    | jq -r '"\(.count) files, \(.bytes / 1048576 | floor) MiB on the remote"' || echo "remote size unknown")
  if [ -z "$failed_folders" ]; then
    push_line_to_loki offsite-backup success "Uploaded ${uploaded_folders// /, } · $remote_size" "$game"
  else
    push_line_to_loki offsite-backup failure "Upload failed for ${failed_folders// /, } · $remote_size" "$game"
  fi
}

# The gitignored files a rebuilt host cannot recover: env files and the rclone login.
# Skipped until OFFSITE_BACKUP_CONFIG_PASSWORD is set; keep that password off this host too.
# Everything plaintext stays inside the 0700 work folder so no secret is ever world-readable.
backup_config_bundle() {
  local config_password work_folder
  config_password=${OFFSITE_BACKUP_CONFIG_PASSWORD:-$(sed -n 's/^OFFSITE_BACKUP_CONFIG_PASSWORD=//p' .env 2>/dev/null | tail -1)}
  if [ -z "$config_password" ]; then
    echo "config bundle skipped: OFFSITE_BACKUP_CONFIG_PASSWORD is not set (root .env)"
    return 0
  fi
  work_folder=$(mktemp -d)
  for config_file in .env platform/site.env games/*/.env; do
    [ -f "$config_file" ] || continue
    mkdir -p "$work_folder/config/repo/$(dirname "$config_file")"
    cp "$config_file" "$work_folder/config/repo/$config_file"
  done
  # home/ maps onto $HOME on the rebuilt machine: SSH keys, git identity, rclone login.
  for home_file in .ssh .gitconfig .config/rclone/rclone.conf; do
    [ -e "$HOME/$home_file" ] || continue
    mkdir -p "$work_folder/config/home/$(dirname "$home_file")"
    cp -r "$HOME/$home_file" "$work_folder/config/home/$home_file"
  done
  mkdir -p "$work_folder/config/system"
  apt-mark showmanual > "$work_folder/config/system/manual-packages.list" 2>/dev/null || true
  tar -czf "$work_folder/bundle.tar.gz" -C "$work_folder/config" .
  OFFSITE_BACKUP_CONFIG_PASSWORD="$config_password" openssl enc -aes-256-cbc -pbkdf2 \
    -pass env:OFFSITE_BACKUP_CONFIG_PASSWORD -in "$work_folder/bundle.tar.gz" -out "$work_folder/bundle.tar.gz.enc"
  if rclone copyto "$work_folder/bundle.tar.gz.enc" "$remote/config-bundles/config-bundle-$run_started_at.tar.gz.enc"; then
    echo "Uploaded config bundle -> $remote/config-bundles/config-bundle-$run_started_at.tar.gz.enc"
    prune_remote_bundles "$remote/config-bundles"
  else
    any_step_failed=1
  fi
  rm -rf "$work_folder"
}

for game_dir in games/*/; do
  game=$(basename "$game_dir")
  uploaded_folders=""
  failed_folders=""
  ready_replicas=$(kubectl -n games get statefulset "$game" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
  if [ "${ready_replicas:-0}" -gt 0 ]; then
    make -s -C "$game_dir" sync || { echo "$game: sync failed, uploading its last synced copy" >&2; any_step_failed=1; }
  fi
  # Archives land flat in <game>/: one per window from data-backups, all of the host's
  # already thinned archive/ tier. Only the game's own archives go up, so a server's
  # bookkeeping files stay here, and their names carry the date.
  archive_pattern=$(make -s -C "$game_dir" print-variable NAME=BACKUP_FILE_PATTERN)
  selected_archives=""
  if [ -d "${game_dir}data-backups" ]; then
    selected_archives=$(newest_archive_per_window "${game_dir}data-backups" "$archive_pattern") \
      || { any_step_failed=1; failed_folders+="data-backups "; }
  fi
  if [ -n "$selected_archives" ]; then
    if upload_to_remote "${game_dir}data-backups" "$remote/$game" --files-from - <<< "$selected_archives"; then
      echo "Uploaded ${game_dir}data-backups -> $remote/$game"
      uploaded_folders+="data-backups "
    else
      any_step_failed=1
      failed_folders+="data-backups "
    fi
  fi
  if [ -n "$(ls -A "${game_dir}data-backups/archive" 2>/dev/null)" ]; then
    if upload_to_remote "${game_dir}data-backups/archive" "$remote/$game" --max-depth 1 --include "$archive_pattern"; then
      echo "Uploaded ${game_dir}data-backups/archive -> $remote/$game"
      uploaded_folders+="data-backups/archive "
    else
      any_step_failed=1
      failed_folders+="data-backups/archive "
    fi
  fi
  # The world tree and the server's config: player stats, mods and lists no archive carries.
  if [ -n "$(ls -A "${game_dir}data" 2>/dev/null)" ]; then
    if upload_data_bundle "$game" "$game_dir"; then
      echo "Uploaded ${game_dir}data -> $remote/$game/data-bundles/$game-data-$run_started_at.tar.gz"
      uploaded_folders+="data-bundle "
      prune_remote_bundles "$remote/$game/data-bundles"
    else
      any_step_failed=1
      failed_folders+="data-bundle "
    fi
  fi
  [ -z "$uploaded_folders$failed_folders" ] || report_game_result "$game" "$uploaded_folders" "$failed_folders"
done

backup_config_bundle

if [ "$any_step_failed" = 0 ]; then report_run_result offsite-backup success; else report_run_result offsite-backup failure; fi
exit "$any_step_failed"
