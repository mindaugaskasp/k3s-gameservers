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

.PHONY: deploy

## Install or upgrade the V Rising server with Helm
##   Reads .env (see .env.example); every value is optional:
##   VRISING_SERVER_PASSWORD   the password players join with; empty lets anyone join
##   VRISING_SERVER_NAME, VRISING_DESCRIPTION, VRISING_MAX_PLAYERS, VRISING_GAME_MODE,
##   VRISING_DIFFICULTY, VRISING_GAME_SETTINGS, VRISING_ADMIN_STEAM_IDS, VRISING_CONNECT_HOST
##   VRISING_DISCORD_WEBHOOK   turns on Discord alerts
deploy: chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@$(LOAD_ENV_FOR_HELM); \
	set_value secrets.serverPassword "$$VRISING_SERVER_PASSWORD"; \
	set_value_if_given server.name "$$VRISING_SERVER_NAME"; \
	set_value_if_given server.description "$$VRISING_DESCRIPTION"; \
	set_value_if_given server.maxPlayers "$$VRISING_MAX_PLAYERS"; \
	set_value_if_given server.gameMode "$$VRISING_GAME_MODE"; \
	set_value_if_given server.difficulty "$$VRISING_DIFFICULTY"; \
	set_value_if_given admins "$$VRISING_ADMIN_STEAM_IDS"; \
	set_value_if_given server.connectHost "$$VRISING_CONNECT_HOST"; \
	set_discord_alerts "$$VRISING_DISCORD_WEBHOOK"; \
	set_game_settings "$$VRISING_GAME_SETTINGS"; \
	helm upgrade --install $(HELM_UPGRADE_FLAGS) "$${helm_flags[@]}"
