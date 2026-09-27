{{- /* The image keeps only the game's rotating autosaves, so this sidecar archives the newest one,
with the world's own two JSON files, into backups/ every backups.intervalMinutes. */ -}}
{{- define "vrising.backupContainer" -}}
- name: backup
  image: alpine:3.20
  command: ["sh", "-c"]
  args:
    - |
      set -u
      cd "$SAVES_DIR"
      # A pod stopped mid-archive leaves its partial one behind.
      rm -f "$BACKUPS_DIR"/.*.tar
      # As PID 1, sh ignores SIGTERM without a trap, and a trap waits out a foreground sleep.
      trap 'exit 0' TERM
      while sleep "$((INTERVAL_MINUTES * 60))" & wait $!; do
        newest_save=$(ls -t v*/"$WORLD_NAME"/AutoSave_*.save.gz 2>/dev/null | head -1)
        [ -n "$newest_save" ] || continue
        world_dir=$(dirname "$newest_save")
        archive="$WORLD_NAME-$(date +%Y%m%d-%H%M%S).tar"
        # Written under a hidden name first, so a half-written archive is never listed as a backup.
        tar -cf "$BACKUPS_DIR/.$archive" "$newest_save" "$world_dir/StartDate.json" "$world_dir/SessionId.json" \
          && mv "$BACKUPS_DIR/.$archive" "$BACKUPS_DIR/$archive"
        ls -t "$BACKUPS_DIR"/*.tar | tail -n "+$((MAX_COUNT + 1))" | xargs -r rm -f
      done
  env:
    - name: SAVES_DIR
      value: {{ printf "%s/Saves" (include "vrising.persistentDataPath" .) | quote }}
    - name: BACKUPS_DIR
      value: {{ include "vrising.backupsPath" . | quote }}
    - name: WORLD_NAME
      value: {{ .Values.server.worldName | quote }}
    - name: INTERVAL_MINUTES
      value: {{ .Values.backups.intervalMinutes | quote }}
    - name: MAX_COUNT
      value: {{ .Values.backups.maxCount | quote }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000 # owns backups/ (the init container's chown); the saves are world-readable
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
  resources:
    {{- toYaml .Values.backupResources | nindent 4 }}
  volumeMounts:
    - name: data
      mountPath: {{ include "vrising.persistentDataPath" . }}
      subPath: persistentdata
      readOnly: true
    - name: data
      mountPath: {{ include "vrising.backupsPath" . }}
      subPath: backups
{{- end -}}
