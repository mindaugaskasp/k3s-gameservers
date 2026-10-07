RELEASE := enshrouded
GAME_TITLE := Enshrouded
GAME_DATA_PATH := /opt/enshrouded
GAME_BACKUP_PATH := /opt/enshrouded/backups
GAME_SHELL := bash
TEMPLATE_SECRET_FLAGS := --set-string secrets.rolePasswords.ADMIN_PASS=REDACTED
# server/ is the steamcmd install, which the updater can always fetch again.
SYNC_DATA_EXCLUDES := server backups
BACKUP_SYNC_RETENTION_DAYS := 5
RESTORE_REQUIRED_ARCHIVE_ENTRY := -index
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
	@$(LOAD_ENV_FOR_HELM); \
	set_value secrets.rolePasswords.ADMIN_PASS "$$ENSHROUDED_ADMIN_PASSWORD"; \
	set_value_if_given secrets.rolePasswords.FRIEND_PASS "$$ENSHROUDED_FRIEND_PASSWORD"; \
	set_discord_alerts "$$ENSHROUDED_DISCORD_WEBHOOK"; \
	set_value_if_given server.connectHost "$$ENSHROUDED_CONNECT_HOST"; \
	set_value_if_given server.name "$$ENSHROUDED_SERVER_NAME"; \
	set_value_if_given server.slotCount "$$ENSHROUDED_SLOT_COUNT"; \
	set_value_if_given server.textChat "$$ENSHROUDED_TEXT_CHAT"; \
	set_value_if_given server.voiceChat "$$ENSHROUDED_VOICE_CHAT"; \
	set_value_if_given gameSettings.PRESET "$$ENSHROUDED_DIFFICULTY"; \
	set_game_settings "$$ENSHROUDED_GAME_SETTINGS"; \
	helm upgrade --install $(HELM_UPGRADE_FLAGS) "$${helm_flags[@]}"

## Run steamcmd now, even if the installed build looks current
force-update:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		supervisorctl start enshrouded-force-update

## Take a game backup right now
backup-now:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		supervisorctl start enshrouded-backup
