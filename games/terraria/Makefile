RELEASE := terraria
GAME_TITLE := Terraria
SHARED_DASHBOARDS :=
GAME_DATA_PATH := /root/.local/share/Terraria/Worlds
GAME_BACKUP_PATH := /root/.local/share/Terraria/Worlds/backups
GAME_SHELL := bash
# Each backup is a copy of the world file itself, not an archive.
BACKUP_FILE_PATTERN := *.bak
include ../../game-server/make/game.mk

.PHONY: deploy secrets-check

# Nothing is required: the chart makes the REST tokens, and the password is optional.
secrets-check:
	@true

## Install or upgrade the Terraria server with Helm
##   Reads .env (see .env.example):
##   TERRARIA_SERVER_PASSWORD   optional, the password players join with
##   TERRARIA_CONNECT_HOST      optional, the public host name
deploy: secrets-check chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@$(LOAD_ENV_FOR_HELM); \
	set_value secrets.serverPassword "$$TERRARIA_SERVER_PASSWORD"; \
	set_value_if_given server.connectHost "$$TERRARIA_CONNECT_HOST"; \
	helm upgrade --install $(HELM_RELEASE_FLAGS) "$${helm_flags[@]}"
