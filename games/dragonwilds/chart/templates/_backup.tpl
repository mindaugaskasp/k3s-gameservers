{{- /* The image keeps no backups, so this sidecar archives SaveGames/ into backups/ every
backups.intervalMinutes, keeping backups.maxCount. */ -}}
{{- define "dragonwilds.backupContainer" -}}
- name: backup
  image: alpine:3.20
  command: ["sh", "-c"]
  args:
    - |
      set -u
      cd "$SAVED_DIR"
      # A pod stopped mid-archive leaves its partial one behind.
      rm -f "$BACKUPS_DIR"/.*.tar.gz
      # As PID 1, sh ignores SIGTERM without a trap, and a trap waits out a foreground sleep.
      trap 'exit 0' TERM
      while sleep "$((INTERVAL_MINUTES * 60))" & wait $!; do
        [ -d SaveGames ] || continue
        archive="SaveGames-$(date +%Y%m%d-%H%M%S).tar.gz"
        # Written under a hidden name first, so a half-written archive is never listed as a backup.
        tar -czf "$BACKUPS_DIR/.$archive" SaveGames && mv "$BACKUPS_DIR/.$archive" "$BACKUPS_DIR/$archive"
        ls -t "$BACKUPS_DIR"/*.tar.gz | tail -n "+$((MAX_COUNT + 1))" | xargs -r rm -f
      done
  env:
    - name: SAVED_DIR
      value: {{ include "dragonwilds.savedPath" . | quote }}
    - name: BACKUPS_DIR
      value: {{ include "dragonwilds.backupsPath" . | quote }}
    - name: INTERVAL_MINUTES
      value: {{ .Values.backups.intervalMinutes | quote }}
    - name: MAX_COUNT
      value: {{ .Values.backups.maxCount | quote }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000 # the server's own uid, so it can read the saves and write backups
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
  resources:
    {{- toYaml .Values.backupResources | nindent 4 }}
  volumeMounts:
    - name: data
      mountPath: {{ include "dragonwilds.serverPath" . }}
      subPath: server
      readOnly: true
    - name: data
      mountPath: {{ include "dragonwilds.backupsPath" . }}
      subPath: backups
{{- end -}}
