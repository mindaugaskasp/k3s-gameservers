{{- define "linuxgsm-game.fullname" -}}
{{ .Release.Name }}
{{- end -}}

{{- define "linuxgsm-game.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: k3s-linuxgsm
app.kubernetes.io/managed-by: {{ .Release.Service }}
lgsm.io/shortname: {{ .Values.game.shortname | quote }}
{{- end -}}

{{- define "linuxgsm-game.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "linuxgsm-game.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag | default .Values.game.shortname }}
{{- end -}}

{{- define "linuxgsm-game.hasNodePort" -}}
{{- $found := "" -}}
{{- range .Values.ports -}}
{{- if .nodePort -}}{{- $found = "true" -}}{{- end -}}
{{- end -}}
{{- $found -}}
{{- end -}}

{{- define "linuxgsm-game.secretName" -}}
{{- if .Values.secretRef -}}
{{ .Values.secretRef }}
{{- else -}}
{{ .Release.Name }}-secrets
{{- end -}}
{{- end -}}
