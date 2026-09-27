{{- /* Where the image keeps the steamcmd install and the world, settings and logs; backups/ is the backup sidecar's. */ -}}
{{- define "vrising.serverPath" -}}/mnt/vrising/server{{- end -}}
{{- define "vrising.persistentDataPath" -}}/mnt/vrising/persistentdata{{- end -}}
{{- define "vrising.backupsPath" -}}/mnt/vrising/backups{{- end -}}
