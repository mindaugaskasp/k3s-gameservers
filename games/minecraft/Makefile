RELEASE := minecraft
GAME_TITLE := Minecraft
GAME_DATA_PATH := /data
GAME_BACKUP_PATH := /backups
GAME_SHELL := bash
TEMPLATE_SECRET_FLAGS := --set-string secrets.rconPassword=REDACTED
# Paper downloads these again on start.
SYNC_DATA_EXCLUDES := cache libraries versions
BACKUP_FILE_PATTERN := *.tgz
BACKUP_ARCHIVE_LIST_COMMAND := tar -tzf
RESTORE_REQUIRED_ARCHIVE_ENTRY := world/level.dat
include ../../game-server/make/game.mk

.PHONY: deploy secrets-check console

secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$MINECRAFT_RCON_PASSWORD" || (echo "MINECRAFT_RCON_PASSWORD is not set" >&2; exit 1)

## Install or upgrade the Minecraft server with Helm
##   Reads .env (see .env.example):
##   MINECRAFT_RCON_PASSWORD    required, for backups and make console
##   MINECRAFT_OPERATORS        optional, comma-separated admin player names
##   MINECRAFT_WHITELIST        optional, comma-separated player names; empty lets anyone join
##   MINECRAFT_DISCORD_WEBHOOK  optional, turns on Discord alerts
##   MINECRAFT_CONNECT_HOST     optional, the public host name shown in alerts
deploy: secrets-check chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@set -a; [ -f .env ] && . ./.env; set +a; \
	extra=(); \
	if [ -n "$$MINECRAFT_OPERATORS" ]; then \
		extra+=(--set-string server.operators="$$MINECRAFT_OPERATORS"); \
	fi; \
	if [ -n "$$MINECRAFT_WHITELIST" ]; then \
		extra+=(--set-string server.whitelist="$$MINECRAFT_WHITELIST"); \
	fi; \
	if [ -n "$$MINECRAFT_DISCORD_WEBHOOK" ]; then \
		extra+=(--set alerts.enabled=true --set-string alerts.discordWebhook="$$MINECRAFT_DISCORD_WEBHOOK"); \
	fi; \
	if [ -n "$$MINECRAFT_CONNECT_HOST" ]; then \
		extra+=(--set-string server.connectHost="$$MINECRAFT_CONNECT_HOST"); \
	fi; \
	helm upgrade --install $(HELM_RELEASE_FLAGS) \
		--set-string secrets.rconPassword="$$MINECRAFT_RCON_PASSWORD" \
		"$${extra[@]}"

## Run one server command over RCON
##   CMD="command"   e.g. make console CMD="list"
console:
	@test -n "$(CMD)" || { echo "usage: make console CMD=\"list\"" >&2; exit 1; }
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- rcon-cli $(CMD)
