{{- /* The webhook the lifecycle hooks post to, unless alerts.secretRef names an existing Secret. */ -}}
{{- define "game-server.discordSecret" -}}
{{- if and .Values.alerts.enabled (not .Values.alerts.secretRef) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "game-server.fullname" . }}-discord
  labels:
    {{- include "game-server.labels" . | nindent 4 }}
type: Opaque
stringData:
  DISCORD_WEBHOOK_URL: {{ .Values.alerts.discordWebhook | quote }}
{{- end }}
{{- end -}}
