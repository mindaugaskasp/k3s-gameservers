{{- /* Terraria's part of the status-metrics sidecar; game-server.statusMetricsContainer includes it. */ -}}
{{- define "status-metrics.env" -}}
{{- $worlds := include "terraria.worldsPath" . -}}
- name: GAMEDIG_GAME
  value: "terrariatshock"
- name: QUERY_PORT
  value: "7777"
- name: TSHOCK_REST_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ include "game-server.secretName" . }}
      key: STATUS_TOKEN
- name: STATUS_DIR
  value: "/var/run/terraria-status"
- name: PERSIST_DIR
  value: {{ $worlds | quote }}
- name: BACKUP_DIR
  value: {{ printf "%s/backups" $worlds | quote }}
- name: BACKUP_MAX_AGE_DAYS
  value: {{ .Values.backups.keepDays | quote }}
- name: BACKUP_MAX_COUNT
  value: "0"
{{- end -}}

{{- define "status-metrics.volumeMounts" -}}
- name: status-share
  mountPath: /var/run/terraria-status
- name: data
  mountPath: {{ include "terraria.worldsPath" . }}
  subPath: worlds
  readOnly: true
{{- end -}}
