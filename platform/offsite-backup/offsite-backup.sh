#!/usr/bin/env bash
# Pulls each running game's world and backups (make sync), then copies the backup archives
# flat into OFFSITE_BACKUP_REMOTE/<game>/ and the world tree into <game>/data/. Nothing on the
# remote is ever deleted; what to keep there is yours. Config files go up as an encrypted
# bundle; see docs/offsite-backups.md.
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
upload_step_timeout=${OFFSITE_BACKUP_STEP_TIMEOUT:-2h}
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
  # Archives land flat in <game>/, the host's archive/ tier among them; their names
  # carry the date, and dotfiles like .play-clock stay off the remote.
  for archive_folder in data-backups data-backups/archive; do
    [ -n "$(ls -A "$game_dir$archive_folder" 2>/dev/null)" ] || continue
    if upload_to_remote "$game_dir$archive_folder" "$remote/$game" --max-depth 1 --exclude ".*"; then
      echo "Uploaded $game_dir$archive_folder -> $remote/$game"
      uploaded_folders+="$archive_folder "
    else
      any_step_failed=1
      failed_folders+="$archive_folder "
    fi
  done
  # The world tree: player stats, mods and lists that no archive carries.
  if [ -n "$(ls -A "${game_dir}data" 2>/dev/null)" ]; then
    if upload_to_remote "${game_dir}data" "$remote/$game/data"; then
      echo "Uploaded ${game_dir}data -> $remote/$game/data"
      uploaded_folders+="data "
    else
      any_step_failed=1
      failed_folders+="data "
    fi
  fi
  [ -z "$uploaded_folders$failed_folders" ] || report_game_result "$game" "$uploaded_folders" "$failed_folders"
done

backup_config_bundle

if [ "$any_step_failed" = 0 ]; then report_run_result offsite-backup success; else report_run_result offsite-backup failure; fi
exit "$any_step_failed"
