#!/usr/bin/env bash
# Prints the backup picked from an fzf list; Tab moves, Enter chooses, Esc cancels.
# Only that path goes to stdout, so a caller can read it. Without a terminal it
# reads the name from stdin instead, which is how the restore is scripted and tested.
set -euo pipefail

backups_dir=${1:?usage: choose-backup.sh DIR PATTERN}
file_pattern=${2:?usage: choose-backup.sh DIR PATTERN}

mapfile -t backups < <(find "$backups_dir" -name "$file_pattern" -printf '%T@ %p\n' 2>/dev/null |
  sort -rn | cut -d' ' -f2-)
test "${#backups[@]}" -gt 0 ||
  { echo "no backups in $backups_dir/ -- run 'make sync' or 'make download-backups' first" >&2; exit 1; }

resolve_backup() {
  local given="$1"
  test -n "$given" || { echo "nothing picked" >&2; exit 1; }
  test -f "$given" || given="$backups_dir/${given#"$backups_dir/"}"
  test -f "$given" || { echo "no such archive: $given" >&2; exit 1; }
  echo "$given"
}

if [ ! -t 0 ]; then
  read -r piped_name || true
  resolve_backup "$piped_name"
  exit 0
fi

if ! command -v fzf >/dev/null; then
  echo "fzf draws the backup list and is not installed." >&2
  read -r -p "Install it now with sudo apt-get install fzf? [y/N] " answer
  case "$answer" in
    [Yy]*) sudo apt-get install -y fzf >&2 || { echo "installing fzf failed" >&2; exit 1; } ;;
    *) echo "install fzf, then run this again" >&2; exit 1 ;;
  esac
fi

picked_line=$(for backup in "${backups[@]}"; do
    printf '%s\t%s\t%s\n' "${backup#"$backups_dir/"}" \
      "$(date -r "$backup" '+%Y-%m-%d %H:%M')" "$(du -h "$backup" | cut -f1)"
  done | fzf --layout=reverse --no-multi --pointer='*' --prompt='backup> ' \
    --header="Tab moves, Enter restores, Esc cancels -- ${#backups[@]} backups, newest first" \
    --bind=tab:down,btab:up)
resolve_backup "$(printf '%s' "$picked_line" | cut -f1)"
