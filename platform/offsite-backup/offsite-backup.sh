#!/usr/bin/env bash
# Pulls each running game's world and backups (make sync), then mirrors games/<game>/data* to
# OFFSITE_BACKUP_REMOTE/<game>/. Files it deletes or overwrites move to <game>/replaced/<run time>/.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

remote=${OFFSITE_BACKUP_REMOTE:?set OFFSITE_BACKUP_REMOTE in the root .env, see docs/offsite-backups.md}
keep_replaced_days=${OFFSITE_BACKUP_KEEP_REPLACED_DAYS:-7}
# rclone --bwlimit format. A full-speed upload can starve game traffic and the host's NIC.
upload_rate_limit=${OFFSITE_BACKUP_BANDWIDTH_LIMIT:-20M}
run_started_at=$(date -u +%Y%m%d-%H%M%S)
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
backup_config_bundle() {
  local config_password staging
  config_password=${OFFSITE_BACKUP_CONFIG_PASSWORD:-$(sed -n 's/^OFFSITE_BACKUP_CONFIG_PASSWORD=//p' .env 2>/dev/null | tail -1)}
  if [ -z "$config_password" ]; then
    echo "config bundle skipped: OFFSITE_BACKUP_CONFIG_PASSWORD is not set (root .env)"
    return 0
  fi
  staging=$(mktemp -d)
  for config_file in .env platform/site.env games/*/.env; do
    [ -f "$config_file" ] || continue
    mkdir -p "$staging/$(dirname "$config_file")"
    cp "$config_file" "$staging/$config_file"
  done
  [ ! -f "$HOME/.config/rclone/rclone.conf" ] || cp "$HOME/.config/rclone/rclone.conf" "$staging/rclone.conf"
  tar -czf "$staging.tar.gz" -C "$staging" .
  CONFIG_BUNDLE_PASSWORD="$config_password" openssl enc -aes-256-cbc -pbkdf2 \
    -pass env:CONFIG_BUNDLE_PASSWORD -in "$staging.tar.gz" -out "$staging.tar.gz.enc"
  if rclone copyto "$staging.tar.gz.enc" "$remote/config-bundle.tar.gz.enc"; then
    echo "Uploaded config bundle -> $remote/config-bundle.tar.gz.enc"
  else
    any_step_failed=1
  fi
  rm -rf "$staging" "$staging.tar.gz" "$staging.tar.gz.enc"
}

# Aged by run folder name, not file time: a moved file keeps its original, older mtime.
purge_before=$(date -u -d "-${keep_replaced_days} days" +%Y%m%d-%H%M%S)

for game_dir in games/*/; do
  game=$(basename "$game_dir")
  uploaded_folders=""
  failed_folders=""
  ready_replicas=$(kubectl -n games get statefulset "$game" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
  if [ "${ready_replicas:-0}" -gt 0 ]; then
    make -s -C "$game_dir" sync || { echo "$game: sync failed, uploading its last synced copy" >&2; any_step_failed=1; }
  fi
  for synced_folder in data data-backups; do
    # An empty folder would mirror as "delete everything" on the remote.
    [ -n "$(ls -A "$game_dir$synced_folder" 2>/dev/null)" ] || continue
    if rclone sync "$game_dir$synced_folder" "$remote/$game/$synced_folder" \
      --bwlimit "$upload_rate_limit" \
      --backup-dir "$remote/$game/replaced/$run_started_at/$synced_folder"; then
      echo "Uploaded $game_dir$synced_folder -> $remote/$game/$synced_folder"
      uploaded_folders+="$synced_folder "
    else
      any_step_failed=1
      failed_folders+="$synced_folder "
    fi
  done
  for replaced_run_folder in $(rclone lsf "$remote/$game/replaced" --dirs-only 2>/dev/null); do
    if [[ "${replaced_run_folder%/}" < "$purge_before" ]]; then
      rclone purge "$remote/$game/replaced/${replaced_run_folder%/}" --drive-use-trash=false || any_step_failed=1
    fi
  done
  [ -z "$uploaded_folders$failed_folders" ] || report_game_result "$game" "$uploaded_folders" "$failed_folders"
done

backup_config_bundle

if [ "$any_step_failed" = 0 ]; then report_run_result offsite-backup success; else report_run_result offsite-backup failure; fi
exit "$any_step_failed"
