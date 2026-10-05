{{- /* Where the image keeps the steamcmd install, with the world, settings and logs under Pal/Saved/;
backups/ holds the image's own backup cron's archives. */ -}}
{{- define "palworld.dataPath" -}}/palworld{{- end -}}
{{- define "palworld.savedPath" -}}/palworld/Pal/Saved{{- end -}}
{{- define "palworld.backupsPath" -}}/palworld/backups{{- end -}}

{{- /* The server binary, never its launch script; "[P]" keeps the pattern from matching a shell that runs it. */ -}}
{{- define "palworld.serverProcessPattern" -}}[P]alServer-Linux{{- end -}}
