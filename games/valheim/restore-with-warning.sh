#!/usr/bin/env bash
# `make restore-backup` with the warning options as flags, because make reads
# --flags as its own:
#   ./restore-with-warning.sh --force-with-message="Restoring soon, please leave" --time=10m
set -euo pipefail
test "$#" -gt 0 || { echo "usage: $0 --force-with-message=\"<text>\" --time=10m" >&2; exit 1; }
quoted_options=""
for option in "$@"; do
  quoted_options+=" $(printf '%q' "$option")"
done
exec make restore-backup RESTORE_WARNING="${quoted_options# }"
