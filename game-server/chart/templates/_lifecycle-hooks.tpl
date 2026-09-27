{{- /* Start and stop hooks for an image with none: status files for the exporter, Discord alerts.
Called with (dict "context" . "statusDir" .. "persistDir" .. "readyCheck" .. "displayName" .. "connectPort" ..);
mounted at /etc/game-hooks, with started.sh and down.sh run from the game's lifecycle. */ -}}
{{- define "game-server.lifecycleHooks" -}}
{{- $context := .context -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "game-server.fullname" $context }}-hooks
  labels:
    {{- include "game-server.labels" $context | nindent 4 }}
data:
  {{- include "game-server.sharedHookScripts" $context | nindent 2 }}

  notify.sh: |
    #!/bin/sh
    set -u
    name={{ .displayName | quote }}
    connect="${CONNECT_HOST:-}${CONNECT_HOST:+:{{ .connectPort }}}"
    case "$1" in
      started) /etc/game-hooks/post-discord-embed.sh "Server online" 3066993 "**$name** is up and accepting connections." Connect "$connect" ;;
      down) /etc/game-hooks/post-discord-embed.sh "Server down" 15548997 "**$name** is shutting down." Connect "$connect" ;;
    esac

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
    /etc/game-hooks/record-uptime.sh {{ .statusDir | quote }} {{ printf "%s/uptime-accumulator.seconds" .persistDir | quote }}
    /etc/game-hooks/notify.sh down
{{- end -}}
