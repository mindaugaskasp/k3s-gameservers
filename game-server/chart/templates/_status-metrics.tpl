{{- /* The status-metrics sidecar (game-server/status-metrics). The game's chart defines
"status-metrics.env" (GAMEDIG_GAME, QUERY_PORT, STATUS_DIR and its own paths) and
"status-metrics.volumeMounts" (the status share and its data, read-only). */ -}}
{{- define "game-server.statusMetricsContainer" -}}
- name: status-metrics
  image: "{{ .Values.statusMetrics.image.repository }}:{{ required "statusMetrics.image.tag is required: run make from games/<game>" .Values.statusMetrics.image.tag }}"
  imagePullPolicy: {{ .Values.statusMetrics.image.pullPolicy }}
  env:
    - name: QUERY_HOST
      value: "127.0.0.1"
    - name: METRICS_PORT
      value: {{ .Values.statusMetrics.port | quote }}
    - name: DATABASE_DIR
      value: "/database/sqlite"
    {{- include "status-metrics.env" . | nindent 4 }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000 # the image's "node" user, numeric so runAsNonRoot can verify it
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
  ports:
    - name: metrics
      containerPort: {{ .Values.statusMetrics.port }}
      protocol: TCP
  livenessProbe:
    httpGet:
      path: /healthz
      port: {{ .Values.statusMetrics.port }}
    periodSeconds: 30
    failureThreshold: 3
  readinessProbe:
    httpGet:
      path: /healthz
      port: {{ .Values.statusMetrics.port }}
    periodSeconds: 10
    failureThreshold: 3
  resources:
    {{- toYaml .Values.statusMetrics.resources | nindent 4 }}
  volumeMounts:
    {{- include "status-metrics.volumeMounts" . | nindent 4 }}
    # The exporter's own path on the volume, off the game's data tree: the game
    # resets ownership across that tree on every start.
    - name: data
      mountPath: /database/sqlite
      subPath: database/sqlite
{{- end -}}

{{- /* Prometheus scrapes every Service port named "metrics" in the games namespace. */ -}}
{{- define "game-server.metricsService" -}}
{{- if .Values.statusMetrics.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "game-server.fullname" . }}-metrics
  labels:
    {{- include "game-server.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    {{- include "game-server.selectorLabels" . | nindent 4 }}
  ports:
    - name: metrics
      port: {{ .Values.statusMetrics.port }}
      targetPort: {{ .Values.statusMetrics.port }}
      protocol: TCP
{{- end }}
{{- end -}}
