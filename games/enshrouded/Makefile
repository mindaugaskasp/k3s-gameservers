RELEASE := enshrouded
GAME_TITLE := Enshrouded
GAME_DATA_PATH := /opt/enshrouded
GAME_BACKUP_PATH := /opt/enshrouded/backups
GAME_SHELL := bash
TEMPLATE_SECRET_FLAGS := --set-string secrets.rolePasswords.ADMIN_PASS=REDACTED
# server/ is the steamcmd install, which the updater can always fetch again.
SYNC_DATA_EXCLUDES := server backups
BACKUP_SYNC_RETENTION_DAYS := 5
RESTORE_REQUIRED_ZIP_ENTRY := -index
include ../../game-server/make/game.mk

.PHONY: deploy secrets-check force-update backup-now

secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$ENSHROUDED_ADMIN_PASSWORD" || (echo "ENSHROUDED_ADMIN_PASSWORD is not set" >&2; exit 1)

## Install or upgrade the Enshrouded server with Helm
##   Reads .env (see .env.example):
##   ENSHROUDED_ADMIN_PASSWORD   required
##   Server name, slots, chat, difficulty and the rest are optional .env overrides.
deploy: secrets-check chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@set -a; [ -f .env ] && . ./.env; set +a; \
	extra=(); \
	if [ -n "$$ENSHROUDED_FRIEND_PASSWORD" ]; then \
		extra+=(--set-string secrets.rolePasswords.FRIEND_PASS="$$ENSHROUDED_FRIEND_PASSWORD"); \
	fi; \
	if [ -n "$$ENSHROUDED_DISCORD_WEBHOOK" ]; then \
		extra+=(--set alerts.enabled=true --set-string alerts.discordWebhook="$$ENSHROUDED_DISCORD_WEBHOOK"); \
	fi; \
	if [ -n "$$ENSHROUDED_CONNECT_HOST" ]; then \
		extra+=(--set-string server.connectHost="$$ENSHROUDED_CONNECT_HOST"); \
	fi; \
	if [ -n "$$ENSHROUDED_SERVER_NAME" ]; then \
		extra+=(--set-string server.name="$$ENSHROUDED_SERVER_NAME"); \
	fi; \
	if [ -n "$$ENSHROUDED_SLOT_COUNT" ]; then \
		extra+=(--set server.slotCount="$$ENSHROUDED_SLOT_COUNT"); \
	fi; \
	if [ -n "$$ENSHROUDED_TEXT_CHAT" ]; then \
		extra+=(--set server.textChat="$$ENSHROUDED_TEXT_CHAT"); \
	fi; \
	if [ -n "$$ENSHROUDED_VOICE_CHAT" ]; then \
		extra+=(--set server.voiceChat="$$ENSHROUDED_VOICE_CHAT"); \
	fi; \
	if [ -n "$$ENSHROUDED_DIFFICULTY" ]; then \
		extra+=(--set-string gameSettings.PRESET="$$ENSHROUDED_DIFFICULTY"); \
	fi; \
	IFS=',' read -ra gs <<< "$$ENSHROUDED_GAME_SETTINGS"; \
	for kv in "$${gs[@]}"; do \
		[ -n "$${kv// }" ] || continue; \
		extra+=(--set-string "gameSettings.$${kv%%=*}=$${kv#*=}"); \
	done; \
	helm upgrade --install $(HELM_RELEASE_FLAGS) \
		--set-string secrets.rolePasswords.ADMIN_PASS="$$ENSHROUDED_ADMIN_PASSWORD" \
		"$${extra[@]}"

## Run steamcmd now, even if the installed build looks current
force-update:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		supervisorctl start enshrouded-force-update

## Take a game backup right now
backup-now:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		supervisorctl start enshrouded-backup
