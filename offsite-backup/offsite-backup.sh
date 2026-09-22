#!/usr/bin/env bash
# Pulls each running game's world and backups (make sync), then mirrors games/<game>/data* to
# OFFSITE_BACKUP_REMOTE/<game>/. Files it deletes or overwrites move to <game>/replaced/<run time>/.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

remote=${OFFSITE_BACKUP_REMOTE:?set OFFSITE_BACKUP_REMOTE in the root .env, see docs/offsite-backups.md}
keep_replaced_days=${OFFSITE_BACKUP_KEEP_REPLACED_DAYS:-7}
run_started_at=$(date -u +%Y%m%d-%H%M%S)
any_step_failed=0

# Kept to send with the run's result, so Grafana shows what a failed run printed.
run_output_file=$(mktemp)
trap 'rm -f "$run_output_file"' EXIT
exec 3>&1 4>&2 > >(tee "$run_output_file") 2>&1
tee_pid=$!

# One line per game for its dashboard, one per run (no game label) for the alerts in monitoring/config/alerting.yaml.
push_line_to_loki() {
  local result=$1 line=$2 game=${3:-}
  [ -n "${LOKI_URL:-}" ] || return 0
  jq -n --arg result "$result" --arg line "$line" --arg game "$game" --arg timestamp "$(date +%s%N)" \
    '{streams: [{stream: ({job: "offsite-backup", result: $result} + (if $game == "" then {} else {game: $game} end)),
      values: [[$timestamp, $line]]}]}' \
    | curl -fsS -m 10 -H 'Content-Type: application/json' -X POST "$LOKI_URL/loki/api/v1/push" --data-binary @- \
    || echo "could not report to Loki" >&2
}

report_run_result() {
  exec 1>&3 2>&4
  wait "$tee_pid" || true
  push_line_to_loki "$1" "$(printf 'offsite backup %s\n' "$1"; tail -n 40 "$run_output_file")"
}

report_game_result() {
  local game=$1 uploaded_folders=${2% } failed_folders=${3% } remote_size
  remote_size=$(rclone size --json "$remote/$game" --exclude "replaced/**" 2>/dev/null \
    | jq -r '"\(.count) files, \(.bytes / 1048576 | floor) MiB on the remote"' || echo "remote size unknown")
  if [ -z "$failed_folders" ]; then
    push_line_to_loki success "Uploaded ${uploaded_folders// /, } · $remote_size" "$game"
  else
    push_line_to_loki failure "Upload failed for ${failed_folders// /, } · $remote_size" "$game"
  fi
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

if [ "$any_step_failed" = 0 ]; then report_run_result success; else report_run_result failure; fi
exit "$any_step_failed"
