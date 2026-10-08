RELEASE := satisfactory
GAME_TITLE := Satisfactory
SHARED_DASHBOARDS :=
GAME_DATA_PATH := /config/saved
GAME_BACKUP_PATH := /config/backups
GAME_SHELL := bash
TEMPLATE_SECRET_FLAGS := --set-string secrets.apiToken=REDACTED
BACKUP_FILE_PATTERN := *.tar.gz
BACKUP_ARCHIVE_LIST_COMMAND := tar -tzf
RESTORE_REQUIRED_ARCHIVE_ENTRY := saved/server
include ../../game-server/make/game.mk

.PHONY: deploy

## Install or upgrade the Satisfactory server with Helm
##   The admin and join passwords are set in game when the server is claimed, so none is required here.
##   Reads .env (see .env.example):
##   SATISFACTORY_API_TOKEN       optional, keeps the exporter's query working with a client-protection password
##   SATISFACTORY_SERVER_NAME, SATISFACTORY_SLOT_COUNT, SATISFACTORY_GAME_SETTINGS, SATISFACTORY_CONNECT_HOST
##   SATISFACTORY_DISCORD_WEBHOOK optional, turns on Discord alerts
deploy: chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@$(LOAD_ENV_FOR_HELM); \
	set_value secrets.apiToken "$$SATISFACTORY_API_TOKEN"; \
	set_discord_alerts "$$SATISFACTORY_DISCORD_WEBHOOK"; \
	set_value_if_given server.connectHost "$$SATISFACTORY_CONNECT_HOST"; \
	set_value_if_given server.name "$$SATISFACTORY_SERVER_NAME"; \
	set_value_if_given server.slotCount "$$SATISFACTORY_SLOT_COUNT"; \
	set_game_settings "$$SATISFACTORY_GAME_SETTINGS"; \
	helm upgrade --install $(HELM_UPGRADE_FLAGS) "$${helm_flags[@]}"
