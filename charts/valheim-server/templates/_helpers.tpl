{{- define "valheim-server.fullname" -}}
{{ .Release.Name }}
{{- end -}}

{{- define "valheim-server.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: k3s-linuxgsm
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "valheim-server.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "valheim-server.secretName" -}}
{{- if .Values.secretRef -}}
{{ .Values.secretRef }}
{{- else -}}
{{ .Release.Name }}-secrets
{{- end -}}
{{- end -}}
