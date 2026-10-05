{{- /* Palworld's part of the status-metrics sidecar; game-server.statusMetricsContainer includes it. */ -}}
{{- define "status-metrics.env" -}}
- name: GAMEDIG_GAME
  value: "palworld"
{{- /* gamedig's palworld protocol asks the REST API, not a game port. */}}
- name: QUERY_PORT
  value: {{ .Values.server.restApiPort | quote }}
- name: PALWORLD_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "game-server.secretName" . }}
      key: ADMIN_PASSWORD
- name: STATUS_DIR
  value: "/var/run/palworld-status"
- name: PERSIST_DIR
  value: {{ include "palworld.savedPath" . | quote }}
- name: BACKUP_DIR
  value: {{ include "palworld.backupsPath" . | quote }}
- name: BACKUP_MAX_AGE_DAYS
  value: {{ .Values.backups.keepDays | quote }}
- name: BACKUP_MAX_COUNT
  value: "0"
{{- end -}}

{{- define "status-metrics.volumeMounts" -}}
- name: status-share
  mountPath: /var/run/palworld-status
- name: data
  mountPath: {{ include "palworld.dataPath" . }}
  readOnly: true
{{- end -}}
