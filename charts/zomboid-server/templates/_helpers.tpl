{{- define "zomboid-server.fullname" -}}
{{ .Release.Name }}
{{- end -}}

{{- define "zomboid-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- /* Immutable once deployed (StatefulSet spec.selector); changing these
requires recreating the workload. https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/ */ -}}
{{- define "zomboid-server.selectorLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "zomboid-server.labels" -}}
helm.sh/chart: {{ include "zomboid-server.chart" . }}
{{ include "zomboid-server.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: k3s-gameservers
{{- end -}}

{{- define "zomboid-server.secretName" -}}
{{- if .Values.secretRef -}}
{{ .Values.secretRef }}
{{- else -}}
{{ .Release.Name }}-secrets
{{- end -}}
{{- end -}}
