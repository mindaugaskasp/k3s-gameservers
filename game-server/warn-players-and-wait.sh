#!/usr/bin/env bash
# Warns everyone online, then waits out the delay before the caller stops the game:
#   warn-players-and-wait.sh --force-with-message="Restoring soon, please leave" --time=10m
# BROADCAST_COMMAND sends one message, e.g. Valheim's broadcast.sh.
set -euo pipefail

# The first warning must land, so a broken broadcast stops the restore while
# the server is still up; later ones are for players who join during the wait.
REPEAT_WARNING_EVERY_SECONDS=60
WARNING_FADE_SECONDS=10
CANCEL_HINT="press Ctrl + C (Cmd + C on Mac) to cancel"

read_arguments() {
  warning_message=""
  requested_time=""
  for argument in "$@"; do
    case "$argument" in
      --force-with-message=*) warning_message="${argument#*=}" ;;
      --time=*) requested_time="${argument#*=}" ;;
      *) echo "unknown option: $argument" >&2; exit 1 ;;
    esac
  done
  test -n "$warning_message" || { echo "--force-with-message= is not set" >&2; exit 1; }
  test -n "$requested_time" || { echo "--time= is not set, e.g. --time=10m or --time=30s" >&2; exit 1; }
}

convert_time_to_seconds() {
  local given="$1"
  case "$given" in
    *[0-9]m) echo $(( ${given%m} * 60 )) ;;
    *[0-9]s) echo "${given%s}" ;;
    *) echo "--time=$given needs a unit: minutes as 10m, seconds as 30s" >&2; exit 1 ;;
  esac
}

send_warning() {
  $BROADCAST_COMMAND "$warning_message" --fadetime "$WARNING_FADE_SECONDS"
}

show_time_left() {
  printf '  restoring in %dm %02ds -- %s\n' $(( $1 / 60 )) $(( $1 % 60 )) "$CANCEL_HINT"
}

cancel_without_restoring() {
  echo; echo "cancelled before the world was touched; nothing was restored" >&2
  exit 130
}

read_arguments "$@"
test -n "${BROADCAST_COMMAND:-}" || { echo "BROADCAST_COMMAND is not set, so nobody can be warned" >&2; exit 1; }
wait_seconds=$(convert_time_to_seconds "$requested_time")
trap cancel_without_restoring INT

send_warning || { echo "the warning did not reach the server, so the restore stops here" >&2; exit 1; }
echo "Warned everyone online. The world is replaced in $requested_time -- $CANCEL_HINT."

deadline=$(( $(date +%s) + wait_seconds ))
while :; do
  seconds_left=$(( deadline - $(date +%s) ))
  [ "$seconds_left" -gt 0 ] || break
  show_time_left "$seconds_left"
  [ "$seconds_left" -lt "$REPEAT_WARNING_EVERY_SECONDS" ] && sleep "$seconds_left" || sleep "$REPEAT_WARNING_EVERY_SECONDS"
  [ $(( deadline - $(date +%s) )) -gt "$WARNING_FADE_SECONDS" ] && send_warning || true
done
