{{- /* Minecraft's part of the status-metrics sidecar; game-server.statusMetricsContainer includes it. */ -}}
{{- define "status-metrics.env" -}}
- name: GAMEDIG_GAME
  value: "minecraft"
- name: QUERY_PORT
  value: "25565"
- name: STATUS_DIR
  value: "/var/run/minecraft-status"
- name: PERSIST_DIR
  value: "/data"
- name: BACKUP_DIR
  value: "/backups"
- name: BACKUP_MAX_AGE_DAYS
  value: {{ .Values.backups.pruneDays | quote }}
- name: BACKUP_MAX_COUNT
  value: "0"
- name: MINECRAFT_OPS_FILE
  value: "/data/ops.json"
- name: MINECRAFT_SERVER_PROPERTIES_FILE
  value: "/data/server.properties"
{{- end -}}

{{- define "status-metrics.volumeMounts" -}}
- name: status-share
  mountPath: /var/run/minecraft-status
- name: data
  mountPath: /data
  subPath: minecraft
  readOnly: true
- name: data
  mountPath: /backups
  subPath: backups
  readOnly: true
{{- end -}}
