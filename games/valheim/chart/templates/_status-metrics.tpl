{{- /* Valheim's part of the status-metrics sidecar; game-server.statusMetricsContainer includes it. */ -}}
{{- define "status-metrics.env" -}}
- name: GAMEDIG_GAME
  value: "valheim"
- name: QUERY_PORT
  value: {{ .Values.statusMetrics.queryPort | quote }}
- name: STATUS_DIR
  value: "/var/run/valheim-status"
- name: PERSIST_DIR
  value: "/config"
- name: ADMIN_LIST_FILE
  value: "/config/adminlist.txt"
- name: WORLD_SAVE_DIR
  value: {{ printf "/config/worlds_local/%s" .Values.server.worldName | quote }}
- name: BACKUP_DIR
  value: "/config/backups"
- name: BACKUP_RECENT_DAYS
  value: {{ .Values.backups.recentDays | quote }}
- name: BACKUP_ARCHIVE_WINDOW_DAYS
  value: {{ join " " .Values.backups.backupArchiveWindowDays | quote }}
{{- if .Values.server.extraArgs }}
# Same string the server starts with; the exporter picks the -modifier pairs out of it.
- name: SERVER_ARGS
  value: {{ .Values.server.extraArgs | quote }}
{{- end }}
{{- end -}}

{{- define "status-metrics.volumeMounts" -}}
- name: status-share
  mountPath: /var/run/valheim-status
- name: data
  mountPath: /config
  subPath: config
  readOnly: true
{{- end -}}
