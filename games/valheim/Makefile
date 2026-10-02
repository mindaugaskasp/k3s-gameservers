RELEASE := valheim
# Valheim ships its own process-health dashboard, with the tiered archive and mods.
SHARED_DASHBOARDS :=
GAME_DATA_PATH := /config
GAME_BACKUP_PATH := /config/backups
TEMPLATE_SECRET_FLAGS := --set-string secrets.serverPassword=REDACTED
RESTORE_REQUIRED_ARCHIVE_ENTRY := config/worlds_local/
include ../../game-server/make/game.mk

.PHONY: deploy secrets-check mods-status approve-mods

# Secrets come from the environment or a gitignored .env here; see .env.example.
secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$VALHEIM_SERVER_PASSWORD" || (echo "VALHEIM_SERVER_PASSWORD is not set (env or .env)" >&2; exit 1); \
	test -n "$$VALHEIM_WORLD_NAME" || (echo "VALHEIM_WORLD_NAME is not set: without it the server starts a new world" >&2; exit 1)

# Discord alerts stay off unless VALHEIM_DISCORD_WEBHOOK is exported.
# connectHost is set the same way, via VALHEIM_CONNECT_HOST, so the public
# DDNS hostname never has to be committed to values.override.yaml.
## Install or upgrade the Valheim server with Helm
##   Reads .env (see .env.example):
##   VALHEIM_SERVER_PASSWORD   required, the password players join with
##   VALHEIM_DISCORD_WEBHOOK   optional, turns on Discord alerts
##   VALHEIM_CONNECT_HOST      optional, the public host name shown to players
##   VALHEIM_ADMIN_STEAM_IDS   optional, space-separated Steam IDs written to adminlist.txt
deploy: secrets-check chart-dependencies
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@$(LOAD_ENV_FOR_HELM); \
	set_value secrets.serverPassword "$$VALHEIM_SERVER_PASSWORD"; \
	set_value server.worldName "$$VALHEIM_WORLD_NAME"; \
	set_value_if_given server.displayName "$$VALHEIM_SERVER_NAME"; \
	set_value_if_given server.seed "$$VALHEIM_SEED"; \
	set_discord_alerts "$$VALHEIM_DISCORD_WEBHOOK"; \
	set_value_if_given server.connectHost "$$VALHEIM_CONNECT_HOST"; \
	set_value_if_given server.adminSteamIds "$$VALHEIM_ADMIN_STEAM_IDS"; \
	helm upgrade --install $(HELM_RELEASE_FLAGS) "$${helm_flags[@]}"

## Show whether mods loaded, why not if they did not, and which plugins are installed
mods-status:
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- sh -c '\
		printf "mods active: "; cat /var/run/valheim-status/mods-active 2>/dev/null || echo "(fail-safe not in use)"; \
		printf "reason:      "; cat /var/run/valheim-status/mods-status 2>/dev/null; echo; \
		printf "approved build: "; cat /config/mods-approved-build 2>/dev/null || echo "(none)"; echo; \
		printf "plugins:     "; ls -1 /config/bepinex/plugins 2>/dev/null | tr "\n" " " || echo "(none)"; echo'

# Records YOUR confirmation that mods work on this build; it tests nothing.
## Confirm the mods work on the running game build, so the fail-safe stops holding them back
##   It tests nothing: it records your confirmation. Then run make restart.
approve-mods:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- /etc/valheim-hooks/approve-mods.sh
	@echo "Restart to load mods: make restart"
