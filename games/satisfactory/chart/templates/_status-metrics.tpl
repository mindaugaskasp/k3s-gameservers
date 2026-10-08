{{- /* Satisfactory's part of the status-metrics sidecar; game-server.statusMetricsContainer includes it. */ -}}
{{- define "status-metrics.env" -}}
- name: GAMEDIG_GAME
  value: "satisfactory"
{{- /* gamedig's satisfactory protocol asks the game port: its query over UDP, the HTTPS API over TCP. */}}
- name: QUERY_PORT
  value: {{ .Values.server.gamePort | quote }}
- name: SATISFACTORY_API_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "game-server.secretName" . }}
      key: API_TOKEN
- name: STATUS_DIR
  value: "/var/run/satisfactory-status"
- name: PERSIST_DIR
  value: {{ include "satisfactory.savedPath" . | quote }}
- name: BACKUP_DIR
  value: {{ include "satisfactory.backupsPath" . | quote }}
- name: BACKUP_MAX_AGE_DAYS
  value: "0"
- name: BACKUP_MAX_COUNT
  value: {{ .Values.backups.maxCount | quote }}
{{- end -}}

{{- define "status-metrics.volumeMounts" -}}
- name: status-share
  mountPath: /var/run/satisfactory-status
- name: data
  mountPath: {{ include "satisfactory.dataPath" . }}
  readOnly: true
{{- end -}}
