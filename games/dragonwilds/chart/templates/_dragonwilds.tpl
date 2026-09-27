{{- /* Where the image keeps the steamcmd install, with the world, settings and logs under Saved/;
backups/ is the backup sidecar's. */ -}}
{{- define "dragonwilds.serverPath" -}}/home/steam/rsdw-dedicated{{- end -}}
{{- define "dragonwilds.savedPath" -}}/home/steam/rsdw-dedicated/RSDragonwilds/Saved{{- end -}}
{{- define "dragonwilds.backupsPath" -}}/home/steam/backups{{- end -}}

{{- /* The server opens its world settings beacon 1111 above the game port. */ -}}
{{- define "dragonwilds.beaconPort" -}}{{ add .Values.server.gamePort 1111 }}{{- end -}}

{{- define "dragonwilds.logFile" -}}{{ include "dragonwilds.savedPath" . }}/Logs/RSDragonwilds.log{{- end -}}

{{- /* The server binary, never its launch script; "[R]" keeps the pattern from matching a shell that runs it. */ -}}
{{- define "dragonwilds.serverProcessPattern" -}}[R]SDragonwildsServer-Linux{{- end -}}
