{{- /* Where the image keeps everything: the steamcmd install in gamefiles/, the saves and
blueprints in saved/, and the backup sidecar's archives in backups/. */ -}}
{{- define "satisfactory.dataPath" -}}/config{{- end -}}
{{- define "satisfactory.savedPath" -}}/config/saved{{- end -}}
{{- define "satisfactory.backupsPath" -}}/config/backups{{- end -}}

{{- /* The server binary, never its launch script; "[F]" keeps the pattern from matching a shell that runs it. */ -}}
{{- define "satisfactory.serverProcessPattern" -}}[F]actoryServer-Linux{{- end -}}

{{- /* The HTTPS API's health check; unauthenticated, self-signed certificate. */ -}}
{{- define "satisfactory.healthCheckCommand" -}}
curl -ksfS -X POST https://127.0.0.1:{{ .Values.server.gamePort }}/api/v1 -H "Content-Type: application/json" -d "{\"function\":\"HealthCheck\",\"data\":{\"clientCustomData\":\"\"}}" >/dev/null 2>&1
{{- end -}}
