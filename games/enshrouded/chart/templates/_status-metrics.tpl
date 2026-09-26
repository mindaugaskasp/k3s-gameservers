{{- /* Where the image keeps the install, saves, logs and backups. */ -}}
{{- define "enshrouded.dataPath" -}}/opt/enshrouded{{- end -}}

{{- /* Enshrouded's part of the status-metrics sidecar; game-server.statusMetricsContainer includes it. */ -}}
{{- define "status-metrics.env" -}}
{{- $data := include "enshrouded.dataPath" . -}}
- name: GAMEDIG_GAME
  value: "enshrouded"
- name: QUERY_PORT
  value: {{ .Values.server.queryPort | quote }}
- name: STATUS_DIR
  value: "/var/run/enshrouded-status"
- name: PERSIST_DIR
  value: {{ $data | quote }}
- name: ENSHROUDED_LOG_FILE
  value: {{ printf "%s/logs/enshrouded_server.log" $data | quote }}
- name: ENSHROUDED_CONFIG_FILE
  value: {{ printf "%s/server/enshrouded_server.json" $data | quote }}
- name: BACKUP_DIR
  value: {{ printf "%s/backups" $data | quote }}
- name: BACKUP_MAX_AGE_DAYS
  value: "0"
- name: BACKUP_MAX_COUNT
  value: {{ .Values.backups.maxCount | quote }}
{{- end -}}

{{- define "status-metrics.volumeMounts" -}}
- name: status-share
  mountPath: /var/run/enshrouded-status
- name: data
  mountPath: {{ include "enshrouded.dataPath" . }}
  readOnly: true
{{- end -}}
