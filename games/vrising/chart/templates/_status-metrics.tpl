{{- /* V Rising's part of the status-metrics sidecar; game-server.statusMetricsContainer includes it. */ -}}
{{- define "status-metrics.env" -}}
{{- $persistentData := include "vrising.persistentDataPath" . -}}
- name: GAMEDIG_GAME
  value: "vrising"
- name: QUERY_PORT
  value: {{ .Values.server.queryPort | quote }}
- name: STATUS_DIR
  value: "/var/run/vrising-status"
- name: PERSIST_DIR
  value: {{ $persistentData | quote }}
- name: VRISING_HOST_SETTINGS_FILE
  value: {{ printf "%s/Settings/ServerHostSettings.json" $persistentData | quote }}
- name: VRISING_GAME_SETTINGS_FILE
  value: {{ printf "%s/Settings/ServerGameSettings.json" $persistentData | quote }}
- name: VRISING_DEFAULT_GAME_SETTINGS_FILE
  value: {{ printf "%s/VRisingServer_Data/StreamingAssets/Settings/ServerGameSettings.json" (include "vrising.serverPath" .) | quote }}
- name: VRISING_VERSION_FILE
  value: {{ printf "%s/VERSION" (include "vrising.serverPath" .) | quote }}
- name: BACKUP_DIR
  value: {{ include "vrising.backupsPath" . | quote }}
- name: BACKUP_MAX_AGE_DAYS
  value: "0"
- name: BACKUP_MAX_COUNT
  value: {{ .Values.backups.maxCount | quote }}
{{- end -}}

{{- define "status-metrics.volumeMounts" -}}
- name: status-share
  mountPath: /var/run/vrising-status
- name: data
  mountPath: {{ include "vrising.persistentDataPath" . }}
  subPath: persistentdata
  readOnly: true
- name: data
  mountPath: {{ include "vrising.serverPath" . }}
  subPath: server
  readOnly: true
- name: data
  mountPath: {{ include "vrising.backupsPath" . }}
  subPath: backups
  readOnly: true
{{- end -}}
