RELEASE := terraria
GAME_TITLE := Terraria
SHARED_DASHBOARDS :=
GAME_DATA_PATH := /root/.local/share/Terraria/Worlds
GAME_BACKUP_PATH := /root/.local/share/Terraria/Worlds/backups
GAME_SHELL := bash
# Each backup is a copy of the world file itself, not an archive.
BACKUP_FILE_PATTERN := *.bak
include ../../game-server/make/game.mk

# The game image: ryshe/terraria plus curl (image/), tagged like the status-metrics image.
GAME_IMAGE_DIR := games/terraria/image
GAME_IMAGE_TAG := $(or $(shell git -C $(REPO_ROOT) log -1 --format=%h -- $(GAME_IMAGE_DIR)),uncommitted)$(shell git -C $(REPO_ROOT) status --porcelain -- $(GAME_IMAGE_DIR) | grep -q . && echo -dirty)
GAME_IMAGE_REPOSITORY := localhost:30500/k3s-gameservers/terraria-server
HELM_RELEASE_FLAGS += --set-string image.tag=$(GAME_IMAGE_TAG)

.PHONY: deploy secrets-check push-game-image

# Nothing is required: the chart makes the REST tokens, and the password is optional.
secrets-check:
	@true

## Install or upgrade the Terraria server with Helm
##   Reads .env (see .env.example):
##   TERRARIA_SERVER_PASSWORD   optional, the password players join with
##   TERRARIA_CONNECT_HOST      optional, the public host name
##   TERRARIA_DISCORD_WEBHOOK   optional, turns on Discord alerts
##   Run make push-game-image first when image/ changed.
deploy: secrets-check chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@$(LOAD_ENV_FOR_HELM); \
	set_value secrets.serverPassword "$$TERRARIA_SERVER_PASSWORD"; \
	set_value_if_given server.connectHost "$$TERRARIA_CONNECT_HOST"; \
	set_discord_alerts "$$TERRARIA_DISCORD_WEBHOOK"; \
	helm upgrade --install $(HELM_RELEASE_FLAGS) "$${helm_flags[@]}"

## Build the game image (image/: ryshe/terraria plus curl) on the newest upstream and push it
##   Then make deploy; to take a new upstream release under the same tag, also make restart.
push-game-image:
	podman build --pull=always --memory=1g -t $(GAME_IMAGE_REPOSITORY):$(GAME_IMAGE_TAG) $(REPO_ROOT)/$(GAME_IMAGE_DIR)
	podman push $(GAME_IMAGE_REPOSITORY):$(GAME_IMAGE_TAG)
