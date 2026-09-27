{{- /* Dragonwilds' part of the status-metrics sidecar; game-server.statusMetricsContainer includes it. */ -}}
{{- define "status-metrics.env" -}}
- name: GAMEDIG_GAME
  value: "dragonwilds"
- name: QUERY_PORT
  value: {{ include "dragonwilds.beaconPort" . | quote }}
- name: STATUS_DIR
  value: "/var/run/dragonwilds-status"
- name: PERSIST_DIR
  value: {{ include "dragonwilds.savedPath" . | quote }}
- name: DRAGONWILDS_LOG_FILE
  value: {{ include "dragonwilds.logFile" . | quote }}
- name: BACKUP_DIR
  value: {{ include "dragonwilds.backupsPath" . | quote }}
- name: BACKUP_MAX_AGE_DAYS
  value: "0"
- name: BACKUP_MAX_COUNT
  value: {{ .Values.backups.maxCount | quote }}
{{- end -}}

{{- define "status-metrics.volumeMounts" -}}
- name: status-share
  mountPath: /var/run/dragonwilds-status
- name: data
  mountPath: {{ include "dragonwilds.serverPath" . }}
  subPath: server
  readOnly: true
- name: data
  mountPath: {{ include "dragonwilds.backupsPath" . }}
  subPath: backups
  readOnly: true
{{- end -}}
