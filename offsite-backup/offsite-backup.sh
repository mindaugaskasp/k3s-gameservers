#!/usr/bin/env bash
# Pulls each running game's world and backups (make sync), then mirrors games/*/data* to
# OFFSITE_BACKUP_REMOTE. Files the mirror deletes or overwrites move to replaced/<run time>/.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

remote=${OFFSITE_BACKUP_REMOTE:?set OFFSITE_BACKUP_REMOTE in the root .env, see docs/offsite-backups.md}
keep_replaced_days=${OFFSITE_BACKUP_KEEP_REPLACED_DAYS:-7}
run_started_at=$(date -u +%Y%m%d-%H%M%S)
failed=0

for game_dir in games/*/; do
  game=$(basename "$game_dir")
  ready_replicas=$(kubectl -n games get statefulset "$game" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
  if [ "${ready_replicas:-0}" -gt 0 ]; then
    make -s -C "$game_dir" sync || { echo "$game: sync failed, uploading its last synced copy" >&2; failed=1; }
  fi
done

for synced_dir in games/*/data games/*/data-backups; do
  # An empty folder would mirror as "delete everything" on the remote.
  [ -n "$(ls -A "$synced_dir" 2>/dev/null)" ] || continue
  rclone sync "$synced_dir" "$remote/$synced_dir" \
    --backup-dir "$remote/replaced/$run_started_at/$synced_dir" || failed=1
  echo "Uploaded $synced_dir -> $remote/$synced_dir"
done

# Aged by run folder name, not file time: a moved file keeps its original, older mtime.
purge_before=$(date -u -d "-${keep_replaced_days} days" +%Y%m%d-%H%M%S)
for run_dir in $(rclone lsf "$remote/replaced" --dirs-only 2>/dev/null); do
  if [[ "${run_dir%/}" < "$purge_before" ]]; then
    rclone purge "$remote/replaced/${run_dir%/}" --drive-use-trash=false || failed=1
  fi
done

exit "$failed"
