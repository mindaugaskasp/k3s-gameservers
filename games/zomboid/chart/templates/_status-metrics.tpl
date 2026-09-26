{{- /* Zomboid's part of the status-metrics sidecar; game-server.statusMetricsContainer includes it. */ -}}
{{- define "status-metrics.env" -}}
- name: GAMEDIG_GAME
  value: "projectzomboid"
- name: QUERY_PORT
  value: {{ .Values.statusMetrics.queryPort | quote }}
- name: STATUS_DIR
  value: "/var/run/zomboid-status"
- name: PERSIST_DIR
  value: "/project-zomboid-config"
- name: ZOMBOID_LOG_DIR
  value: "/project-zomboid-config/Logs"
- name: ZOMBOID_SANDBOX_FILE
  value: {{ printf "/project-zomboid-config/Server/%s_SandboxVars.lua" .Values.server.name | quote }}
- name: ZOMBOID_ACCOUNTS_DATABASE_FILE
  value: {{ printf "/project-zomboid-config/db/%s.db" .Values.server.name | quote }}
- name: ZOMBOID_PLAYERS_DATABASE_FILE
  value: {{ printf "/project-zomboid-config/Saves/Multiplayer/%s/players.db" .Values.server.name | quote }}
- name: BACKUP_DIR
  value: "/project-zomboid-config/backups/period"
- name: BACKUP_MAX_AGE_DAYS
  value: "0"
- name: BACKUP_MAX_COUNT
  value: {{ .Values.backups.count | quote }}
{{- end -}}

{{- define "status-metrics.volumeMounts" -}}
- name: status-share
  mountPath: /var/run/zomboid-status
- name: data
  mountPath: /project-zomboid-config
  subPath: config
  readOnly: true
{{- end -}}
