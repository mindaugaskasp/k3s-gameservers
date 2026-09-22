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

# Aged by run folder name, not file time: a moved file keeps its original, older mtime.
purge_before=$(date -u -d "-${keep_replaced_days} days" +%Y%m%d-%H%M%S)

for game_dir in games/*/; do
  game=$(basename "$game_dir")
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
    else
      any_step_failed=1
    fi
  done
  for replaced_run_folder in $(rclone lsf "$remote/$game/replaced" --dirs-only 2>/dev/null); do
    if [[ "${replaced_run_folder%/}" < "$purge_before" ]]; then
      rclone purge "$remote/$game/replaced/${replaced_run_folder%/}" --drive-use-trash=false || any_step_failed=1
    fi
  done
done

exit "$any_step_failed"
