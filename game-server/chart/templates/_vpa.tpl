{{- /* Recommendations for the game container only; the bounds are the game's verticalPodAutoscaler values. */ -}}
{{- define "game-server.vpa" -}}
{{- if .Values.verticalPodAutoscaler.enabled }}
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: {{ include "game-server.fullname" . }}
  labels:
    {{- include "game-server.labels" . | nindent 4 }}
spec:
  targetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: {{ include "game-server.fullname" . }}
  updatePolicy:
    updateMode: {{ .Values.verticalPodAutoscaler.updateMode | quote }}
  resourcePolicy:
    containerPolicies:
      - containerName: gameserver
        minAllowed:
          {{- toYaml .Values.verticalPodAutoscaler.minAllowed | nindent 10 }}
        maxAllowed:
          {{- toYaml .Values.verticalPodAutoscaler.maxAllowed | nindent 10 }}
      - containerName: status-metrics
        mode: "Off"
{{- end }}
{{- end -}}
