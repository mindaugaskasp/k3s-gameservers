RELEASE := vrising
GAME_TITLE := V Rising
GAME_DATA_PATH := /mnt/vrising/persistentdata
GAME_BACKUP_PATH := /mnt/vrising/backups
GAME_SHELL := bash
TEMPLATE_SECRET_FLAGS := --set-string secrets.serverPassword=REDACTED
# Each backup is a plain tar of one autosave, which is gzipped already.
BACKUP_FILE_PATTERN := *.tar
BACKUP_ARCHIVE_LIST_COMMAND := tar -tf
RESTORE_REQUIRED_ARCHIVE_ENTRY := .save.gz
include ../../game-server/make/game.mk

# Each .env setting and the chart value it overrides; an empty one keeps what values.override.yaml sets.
ENV_SETTING_VALUES := VRISING_SERVER_NAME=server.name VRISING_DESCRIPTION=server.description \
	VRISING_MAX_PLAYERS=server.maxPlayers VRISING_GAME_MODE=server.gameMode \
	VRISING_DIFFICULTY=server.difficulty VRISING_ADMIN_STEAM_IDS=admins VRISING_CONNECT_HOST=server.connectHost

.PHONY: deploy

## Install or upgrade the V Rising server with Helm
##   Reads .env (see .env.example); every value is optional:
##   VRISING_SERVER_PASSWORD   the password players join with; empty lets anyone join
##   VRISING_SERVER_NAME, VRISING_DESCRIPTION, VRISING_MAX_PLAYERS, VRISING_GAME_MODE,
##   VRISING_DIFFICULTY, VRISING_GAME_SETTINGS, VRISING_ADMIN_STEAM_IDS, VRISING_CONNECT_HOST
##   VRISING_DISCORD_WEBHOOK   turns on Discord alerts
deploy: chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@set -a; [ -f .env ] && . ./.env; set +a; \
	escape_commas() { printf '%s' "$${1//,/\\,}"; }; \
	extra=(); \
	for setting in $(ENV_SETTING_VALUES); do \
		env_name=$${setting%%=*}; \
		[ -z "$${!env_name}" ] || extra+=(--set-string "$${setting#*=}=$$(escape_commas "$${!env_name}")"); \
	done; \
	IFS=',' read -ra game_settings <<< "$$VRISING_GAME_SETTINGS"; \
	for game_setting in "$${game_settings[@]}"; do \
		game_setting=$${game_setting// }; \
		[ -n "$$game_setting" ] || continue; \
		extra+=(--set-string "gameSettings.$${game_setting%%=*}=$${game_setting#*=}"); \
	done; \
	if [ -n "$$VRISING_DISCORD_WEBHOOK" ]; then \
		extra+=(--set alerts.enabled=true --set-string alerts.discordWebhook="$$VRISING_DISCORD_WEBHOOK"); \
	fi; \
	helm upgrade --install $(HELM_RELEASE_FLAGS) \
		--set-string secrets.serverPassword="$$(escape_commas "$$VRISING_SERVER_PASSWORD")" \
		"$${extra[@]}"
