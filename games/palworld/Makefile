RELEASE := palworld
GAME_TITLE := Palworld
SHARED_DASHBOARDS :=
GAME_DATA_PATH := /palworld/Pal/Saved
GAME_BACKUP_PATH := /palworld/backups
GAME_SHELL := bash
TEMPLATE_SECRET_FLAGS := --set-string secrets.adminPassword=REDACTED --set-string secrets.serverPassword=REDACTED
BACKUP_FILE_PATTERN := *.tar.gz
BACKUP_ARCHIVE_LIST_COMMAND := tar -tzf
RESTORE_REQUIRED_ARCHIVE_ENTRY := SaveGames/
include ../../game-server/make/game.mk

.PHONY: deploy secrets-check backup-now

secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$PALWORLD_ADMIN_PASSWORD" || (echo "PALWORLD_ADMIN_PASSWORD is not set (env or .env)" >&2; exit 1)

## Install or upgrade the Palworld server with Helm
##   Reads .env (see .env.example):
##   PALWORLD_ADMIN_PASSWORD   required, admin commands and the REST API's basic auth
##   PALWORLD_SERVER_PASSWORD  optional, the password players join with; empty lets anyone join
##   PALWORLD_SERVER_NAME, PALWORLD_SLOT_COUNT, PALWORLD_GAME_SETTINGS, PALWORLD_CONNECT_HOST
##   PALWORLD_DISCORD_WEBHOOK  optional, turns on Discord alerts
deploy: secrets-check chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@$(LOAD_ENV_FOR_HELM); \
	set_value secrets.adminPassword "$$PALWORLD_ADMIN_PASSWORD"; \
	set_value secrets.serverPassword "$$PALWORLD_SERVER_PASSWORD"; \
	set_discord_alerts "$$PALWORLD_DISCORD_WEBHOOK"; \
	set_value_if_given server.connectHost "$$PALWORLD_CONNECT_HOST"; \
	set_value_if_given server.name "$$PALWORLD_SERVER_NAME"; \
	set_value_if_given server.slotCount "$$PALWORLD_SLOT_COUNT"; \
	set_game_settings "$$PALWORLD_GAME_SETTINGS"; \
	helm upgrade --install $(HELM_RELEASE_FLAGS) "$${helm_flags[@]}"

## Take a game backup right now
backup-now:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- backup
