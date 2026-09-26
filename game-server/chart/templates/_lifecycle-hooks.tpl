{{- /* Start and stop hooks for a game whose image has none: they write the status files the
exporter reads (last start, lifetime uptime) and post Discord alerts when the image has curl.
Called with (dict "context" . "statusDir" .. "persistDir" .. "readyCheck" .. "displayName" .. "connectPort" ..);
the game mounts the ConfigMap at /etc/game-hooks and runs started.sh and down.sh from its lifecycle. */ -}}
{{- define "game-server.lifecycleHooks" -}}
{{- $context := .context -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "game-server.fullname" $context }}-hooks
  labels:
    {{- include "game-server.labels" $context | nindent 4 }}
data:
  notify.sh: |
    #!/bin/sh
    # Posts a Discord embed for a lifecycle event. Never fails the caller.
    set -u
    [ -n "${DISCORD_WEBHOOK_URL:-}" ] && command -v curl >/dev/null || exit 0
    name={{ .displayName | quote }}
    connect="${CONNECT_HOST:-}${CONNECT_HOST:+:{{ .connectPort }}}"
    json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
    case "$1" in
      started) title="Server online"; color=3066993; desc="**$name** is up and accepting connections." ;;
      down) title="Server down"; color=15548997; desc="**$name** is shutting down." ;;
      *) title="Server event"; color=9807270; desc="**$name**: $1" ;;
    esac
    fields="[]"
    [ -n "$connect" ] && fields="[{\"name\":\"Connect\",\"value\":\"$(json_escape "$connect")\",\"inline\":true}]"
    payload="{\"embeds\":[{\"title\":\"$title\",\"description\":\"$(json_escape "$desc")\",\"color\":$color,\"fields\":$fields,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}]}"
    curl -fsS -X POST -H "Content-Type: application/json" -d "$payload" "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true

  # postStart must return fast (kubelet holds the container until it does), so the wait is backgrounded.
  started.sh: |
    #!/bin/sh
    nohup /etc/game-hooks/started-wait.sh >/tmp/started-hook.log 2>&1 &
    exit 0

  # Waits up to an hour for the server to answer; a first start may download or generate the world.
  started-wait.sh: |
    #!/bin/bash
    set -u
    status_dir={{ .statusDir | quote }}
    mkdir -p "$status_dir" && chmod 0777 "$status_dir"
    for attempt in $(seq 1 360); do
      if {{ .readyCheck }}; then
        date +%s > "$status_dir/last-started.timestamp"
        exec /etc/game-hooks/notify.sh started
      fi
      sleep 10
    done
    echo "started-hook: the server never answered, giving up" >&2

  # Runs before SIGTERM and counts against terminationGracePeriodSeconds, so it stays fast.
  down.sh: |
    #!/bin/sh
    set -u
    status_dir={{ .statusDir | quote }}
    uptime_file={{ printf "%s/uptime-accumulator.seconds" .persistDir | quote }}
    started_at=$(cat "$status_dir/last-started.timestamp" 2>/dev/null || echo 0)
    case "$started_at" in ''|*[!0-9]*) started_at=0 ;; esac
    elapsed=0
    [ "$started_at" -gt 0 ] && elapsed=$(( $(date +%s) - started_at ))
    [ "$elapsed" -lt 0 ] && elapsed=0
    prior=$(cat "$uptime_file" 2>/dev/null || echo 0)
    case "$prior" in ''|*[!0-9]*) prior=0 ;; esac
    echo $((prior + elapsed)) > "$uptime_file"
    /etc/game-hooks/notify.sh down
{{- end -}}
