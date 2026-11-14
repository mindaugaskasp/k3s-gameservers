# Sourced by offsite-backup.sh and restore-drill.sh. push_line_to_loki sends one line per game
# (game label set) or per run (no game label); report_run_result needs the caller's
# run_output_file and tee_pid. Both are no-ops without LOKI_URL.
push_line_to_loki() {
  local job=$1 result=$2 line=$3 game=${4:-}
  [ -n "${LOKI_URL:-}" ] || return 0
  jq -n --arg job "$job" --arg result "$result" --arg line "$line" --arg game "$game" --arg timestamp "$(date +%s%N)" \
    '{streams: [{stream: ({job: $job, result: $result} + (if $game == "" then {} else {game: $game} end)),
      values: [[$timestamp, $line]]}]}' \
    | curl -fsS -m 10 -H 'Content-Type: application/json' -X POST "$LOKI_URL/loki/api/v1/push" --data-binary @- \
    || echo "could not report to Loki" >&2
}

report_run_result() {
  local job=$1 result=$2
  exec 1>&3 2>&4
  wait "$tee_pid" || true
  push_line_to_loki "$job" "$result" "$(printf '%s %s\n' "$job" "$result"; tail -n 40 "$run_output_file")"
}
