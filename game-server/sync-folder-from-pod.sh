#!/usr/bin/env bash
# Pulls a folder out of a running game pod into a local mirror, so what the server deleted
# goes away here too. Extracts into <folder>.new and swaps it in only once complete, so a
# failed or empty pull keeps the last good copy.
# Usage: sync-folder-from-pod.sh <namespace> <pod> <folder in the pod> <local folder> [excluded folder ...]
# REQUIRED_FILE_PATTERN=*.zip   refuse to swap in a mirror without a file matching it
set -euo pipefail
namespace=$1 pod=$2 pod_folder=$3 local_folder=$4
shift 4
required_file_pattern=${REQUIRED_FILE_PATTERN:-}
exclude_flags=()
for excluded_folder in "$@"; do exclude_flags+=(--exclude "./$excluded_folder"); done

rm -rf "$local_folder.new"
mkdir -p "$local_folder.new"
kubectl -n "$namespace" exec "$pod" -c gameserver -- \
  tar cf - -C "$pod_folder" "${exclude_flags[@]}" . | tar xf - -C "$local_folder.new"
if [ -n "$required_file_pattern" ] && ! ls "$local_folder.new"/$required_file_pattern >/dev/null 2>&1; then
  echo "$pod_folder holds nothing matching '$required_file_pattern'; keeping $local_folder/ unchanged" >&2
  rm -rf "$local_folder.new"
  exit 1
fi
rm -rf "$local_folder.old"
[ ! -d "$local_folder" ] || mv "$local_folder" "$local_folder.old"
mv "$local_folder.new" "$local_folder"
rm -rf "$local_folder.old"
echo "Synced $pod_folder -> $local_folder/"
