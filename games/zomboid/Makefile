RELEASE := zomboid
GAME_TITLE := Project Zomboid
MODS_FILE := mods.json
VALUE_FILES := values.override.yaml $(MODS_FILE)
GAME_DATA_PATH := /project-zomboid-config
GAME_BACKUP_PATH := /project-zomboid-config/backups
GAME_SHELL := bash
STATUS_KINDS := statefulset,pod,pvc,svc,cronjob
TEMPLATE_SECRET_FLAGS := --set-string secrets.adminPassword=REDACTED --set-string secrets.rconPassword=REDACTED
BACKUP_SYNC_RETENTION_DAYS := 5
RESTORE_REQUIRED_ZIP_ENTRY := Saves/Multiplayer/
# Game updates apply on restart, so none are scheduled while the game is scaled to 0.
AFTER_SCALE_DOWN_ZERO = $(MAKE) --no-print-directory suspend-update-cron SUSPEND=true
AFTER_SCALE_UP = $(MAKE) --no-print-directory suspend-update-cron SUSPEND=false
include ../../game-server/make/game.mk

.PHONY: deploy secrets-check suspend-update-cron announce mods add-mod disable-mod enable-mod remove-mod

secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$ZOMBOID_ADMIN_PASSWORD" || (echo "ZOMBOID_ADMIN_PASSWORD is not set" >&2; exit 1); \
	test -n "$$ZOMBOID_RCON_PASSWORD" || (echo "ZOMBOID_RCON_PASSWORD is not set" >&2; exit 1)

## Install or upgrade the Project Zomboid server with Helm
##   Reads .env (see .env.example):
##   ZOMBOID_ADMIN_PASSWORD    required
##   ZOMBOID_RCON_PASSWORD     required
##   ZOMBOID_SERVER_PASSWORD   optional, the password players join with
##   ZOMBOID_DISCORD_WEBHOOK   optional, turns on Discord alerts
##   ZOMBOID_CONNECT_HOST      optional, the public host name shown to players
deploy: secrets-check chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@set -a; [ -f .env ] && . ./.env; set +a; \
	extra=(); \
	if [ -n "$$ZOMBOID_SERVER_PASSWORD" ]; then \
		extra+=(--set-string secrets.serverPassword="$$ZOMBOID_SERVER_PASSWORD"); \
	fi; \
	if [ -n "$$ZOMBOID_DISCORD_WEBHOOK" ]; then \
		extra+=(--set alerts.enabled=true --set-string alerts.discordWebhook="$$ZOMBOID_DISCORD_WEBHOOK"); \
	fi; \
	if [ -n "$$ZOMBOID_CONNECT_HOST" ]; then \
		extra+=(--set-string server.connectHost="$$ZOMBOID_CONNECT_HOST"); \
	fi; \
	helm upgrade --install $(HELM_RELEASE_FLAGS) \
		--set-string secrets.adminPassword="$$ZOMBOID_ADMIN_PASSWORD" \
		--set-string secrets.rconPassword="$$ZOMBOID_RCON_PASSWORD" \
		"$${extra[@]}"

# No update restarts while the game is scaled to 0.
suspend-update-cron:
	@if kubectl -n $(NAMESPACE) get cronjob/$(RELEASE)-update >/dev/null 2>&1; then \
		kubectl -n $(NAMESPACE) patch cronjob/$(RELEASE)-update -p '{"spec":{"suspend":$(SUSPEND)}}'; fi

## Send an in-game message to every connected player over RCON
##   MSG="text"   the message
##   e.g. make announce MSG="Restarting in 5 minutes"
announce:
	@test -n "$(MSG)" || { echo "usage: make announce MSG=\"your message\"" >&2; exit 1; }
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- env MSG="$(MSG)" sh -c \
		'rcon -a 127.0.0.1:$${PORT_TCP_RCON:-27015} -p "$$RCON_PASSWORD" "servermsg \"$$MSG\""'

include mods.mk
