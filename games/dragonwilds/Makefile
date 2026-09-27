RELEASE := dragonwilds
GAME_TITLE := RuneScape: Dragonwilds
SHARED_DASHBOARDS :=
GAME_DATA_PATH := /home/steam/rsdw-dedicated/RSDragonwilds/Saved
GAME_BACKUP_PATH := /home/steam/backups
GAME_SHELL := bash
TEMPLATE_SECRET_FLAGS := --set-string secrets.serverPassword=REDACTED --set-string secrets.adminPassword=REDACTED \
	--set-string server.ownerId=REDACTED --set-string server.worldName=REDACTED
BACKUP_FILE_PATTERN := *.tar.gz
BACKUP_ARCHIVE_LIST_COMMAND := tar -tzf
RESTORE_REQUIRED_ARCHIVE_ENTRY := SaveGames/
include ../../game-server/make/game.mk

.PHONY: deploy secrets-check

secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$DRAGONWILDS_OWNER_ID" || (echo "DRAGONWILDS_OWNER_ID is not set (env or .env)" >&2; exit 1); \
	test -n "$$DRAGONWILDS_WORLD_NAME" || (echo "DRAGONWILDS_WORLD_NAME is not set: without it the server starts a new world" >&2; exit 1); \
	test -n "$$DRAGONWILDS_ADMIN_PASSWORD" || (echo "DRAGONWILDS_ADMIN_PASSWORD is not set (env or .env)" >&2; exit 1)

## Install or upgrade the RuneScape: Dragonwilds server with Helm
##   Reads .env (see .env.example):
##   DRAGONWILDS_OWNER_ID         required, the owner's player ID from the game's settings screen
##   DRAGONWILDS_WORLD_NAME       required, the world's name; a new name starts a NEW world
##   DRAGONWILDS_ADMIN_PASSWORD   required, opens the in-game server management screen
##   DRAGONWILDS_SERVER_PASSWORD  optional, the password players join with; empty lets anyone join
##   DRAGONWILDS_SERVER_NAME, DRAGONWILDS_ADMINS, DRAGONWILDS_CONNECT_HOST
##   DRAGONWILDS_DISCORD_WEBHOOK  optional, turns on Discord alerts
deploy: secrets-check chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@$(LOAD_ENV_FOR_HELM); \
	set_value server.ownerId "$$DRAGONWILDS_OWNER_ID"; \
	set_value server.worldName "$$DRAGONWILDS_WORLD_NAME"; \
	set_value secrets.adminPassword "$$DRAGONWILDS_ADMIN_PASSWORD"; \
	set_value secrets.serverPassword "$$DRAGONWILDS_SERVER_PASSWORD"; \
	set_value_if_given server.name "$$DRAGONWILDS_SERVER_NAME"; \
	set_value_if_given server.admins "$$DRAGONWILDS_ADMINS"; \
	set_value_if_given server.connectHost "$$DRAGONWILDS_CONNECT_HOST"; \
	set_discord_alerts "$$DRAGONWILDS_DISCORD_WEBHOOK"; \
	helm upgrade --install $(HELM_RELEASE_FLAGS) "$${helm_flags[@]}"
