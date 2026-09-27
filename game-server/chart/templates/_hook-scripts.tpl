{{- /* The scripts every game's hooks ConfigMap carries beside its own, as entries under its data:.
Each game's notify.sh and down.sh call them from the same folder. */ -}}
{{- define "game-server.sharedHookScripts" -}}
# post-discord-embed.sh <title> <colour> <description> [<field name> <field value>]...
# A field with an empty value is left out. Never fails its caller.
post-discord-embed.sh: |
  #!/bin/sh
  [ -n "${DISCORD_WEBHOOK_URL:-}" ] && command -v curl >/dev/null || exit 0
  json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
  title=$1 colour=$2 description=$3
  shift 3
  fields=""
  while [ "$#" -ge 2 ]; do
    [ -n "$2" ] && fields="${fields:+$fields,}{\"name\":\"$(json_escape "$1")\",\"value\":\"$(json_escape "$2")\",\"inline\":true}"
    shift 2
  done
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  payload="{\"embeds\":[{\"title\":\"$(json_escape "$title")\",\"description\":\"$(json_escape "$description")\",\"color\":$colour,\"fields\":[$fields],\"timestamp\":\"$timestamp\"}]}"
  curl -fsS -X POST -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true

# record-uptime.sh <status dir> <uptime file>: adds the session since last-started.timestamp to
# the lifetime total, which Prometheus can't answer from its 7 days.
record-uptime.sh: |
  #!/bin/sh
  status_dir=$1 uptime_file=$2
  started_at=$(cat "$status_dir/last-started.timestamp" 2>/dev/null || echo 0)
  case "$started_at" in ''|*[!0-9]*) started_at=0 ;; esac
  session_seconds=0
  [ "$started_at" -gt 0 ] && session_seconds=$(( $(date +%s) - started_at ))
  [ "$session_seconds" -lt 0 ] && session_seconds=0
  recorded_seconds=$(cat "$uptime_file" 2>/dev/null || echo 0)
  case "$recorded_seconds" in ''|*[!0-9]*) recorded_seconds=0 ;; esac
  echo $((recorded_seconds + session_seconds)) > "$uptime_file"
{{- end -}}
