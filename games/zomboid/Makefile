SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
export KUBECONFIG ?= $(HOME)/.kube/config
CHART := ../../charts/zomboid-server
RELEASE := zomboid
NAMESPACE := games
VALUES := values.override.yaml
MODS_FILE := mods.json
DATA_DIR := data
BACKUP_DIR := data-backups
REPO_ROOT := $(abspath ../..)
include ../metrics-image.mk
include ../../make/help.mk
BACKUP_RETENTION_DAYS := 5

.PHONY: help init-env mods add-mod disable-mod enable-mod remove-mod lint template deploy status logs logs-metrics \
	restart scale-down-zero scale-up suspend-update-cron shell port-forward-metrics dashboards secrets-check \
	uninstall build-metrics-image push-metrics-image players backups announce \
	sync sync-data sync-backups install-sync-timer restore-backup _restore-run download-backups read-player-db reset-player-stats


## Check the Helm chart and values.override.yaml with helm lint
lint:
	helm lint $(CHART) -f $(VALUES) -f $(MODS_FILE) --set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG)

## Render the manifests locally, with the password redacted; needs no cluster
template:
	helm template $(RELEASE) $(CHART) -f $(VALUES) -f $(MODS_FILE) -n $(NAMESPACE) \
		--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG) \
		--set-string secrets.adminPassword=REDACTED \
		--set-string secrets.rconPassword=REDACTED

secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$ZOMBOID_ADMIN_PASSWORD" || (echo "ZOMBOID_ADMIN_PASSWORD is not set" >&2; exit 1); \
	test -n "$$ZOMBOID_RCON_PASSWORD" || (echo "ZOMBOID_RCON_PASSWORD is not set" >&2; exit 1)

## Build the status-metrics image with podman
build-metrics-image:
	podman build --memory=512m $(STATUS_METRICS_BUILD_FLAGS) -t $(STATUS_METRICS_IMAGE) $(STATUS_METRICS_DIR)

# Into the in-cluster registry k3s pulls from; the pod picks it up on its next start.
## Build the status-metrics image and push it to the in-cluster registry
##   The pod picks it up on its next start.
push-metrics-image: build-metrics-image
	podman push $(STATUS_METRICS_IMAGE)

## Install or upgrade the Project Zomboid server with Helm
##   Reads .env (see .env.example):
##   ZOMBOID_ADMIN_PASSWORD    required
##   ZOMBOID_RCON_PASSWORD     required
##   ZOMBOID_SERVER_PASSWORD   optional, the password players join with
##   ZOMBOID_DISCORD_WEBHOOK   optional, turns on Discord alerts
##   ZOMBOID_CONNECT_HOST      optional, the public host name shown to players
deploy: secrets-check
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
	helm upgrade --install $(RELEASE) $(CHART) \
		-f $(VALUES) -f $(MODS_FILE) \
		-n $(NAMESPACE) \
		--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG) \
		--set-string secrets.adminPassword="$$ZOMBOID_ADMIN_PASSWORD" \
		--set-string secrets.rconPassword="$$ZOMBOID_RCON_PASSWORD" \
		"$${extra[@]}"

## Show this game's StatefulSet, pod, volume and services
status:
	kubectl -n $(NAMESPACE) get statefulset,pod,pvc,svc,cronjob -l app.kubernetes.io/instance=$(RELEASE)

## Follow the game server log
logs:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c gameserver

## Follow the status-metrics sidecar log
logs-metrics:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c status-metrics

## Restart the game server pod, which is also how game updates apply
restart:
	kubectl -n $(NAMESPACE) rollout restart statefulset/$(RELEASE)

## Stop the game server by scaling it to 0 pods, and pause update restarts; its data is kept
scale-down-zero:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=0
	@$(MAKE) --no-print-directory suspend-update-cron SUSPEND=true

## Start the game server again after scale-down-zero, and resume update restarts
scale-up:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=1
	@$(MAKE) --no-print-directory suspend-update-cron SUSPEND=false

# No update restarts while the game is scaled to 0.
suspend-update-cron:
	@if kubectl -n $(NAMESPACE) get cronjob/$(RELEASE)-update >/dev/null 2>&1; then \
		kubectl -n $(NAMESPACE) patch cronjob/$(RELEASE)-update -p '{"spec":{"suspend":$(SUSPEND)}}'; fi

## Open a shell in the running game server container
shell:
	kubectl -n $(NAMESPACE) exec -it $(RELEASE)-0 -c gameserver -- bash

## Print the current player count from status-metrics
players:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c status-metrics -- \
		wget -qO- http://127.0.0.1:9101/metrics | grep game_server_players

## List the game's own period, startup and version backups
backups:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		sh -c 'cd /project-zomboid-config/backups && ls -la period startup version 2>/dev/null'

## Send an in-game message to every connected player over RCON
##   MSG="text"   the message
##   e.g. make announce MSG="Restarting in 5 minutes"
announce:
	@test -n "$(MSG)" || { echo "usage: make announce MSG=\"your message\"" >&2; exit 1; }
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- env MSG="$(MSG)" sh -c \
		'rcon -a 127.0.0.1:$${PORT_TCP_RCON:-27015} -p "$$RCON_PASSWORD" "servermsg \"$$MSG\""'

## Copy config, the install and backups from the pod into data/ and data-backups/
sync: sync-data sync-backups

sync-data:
	@mkdir -p $(DATA_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C /project-zomboid-config --exclude=./backups . | tar xf - -C $(DATA_DIR)
	@echo "Synced /project-zomboid-config -> $(DATA_DIR)/"

sync-backups:
	@mkdir -p $(BACKUP_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C /project-zomboid-config/backups . | tar xf - -C $(BACKUP_DIR)
	@find $(BACKUP_DIR) -type f -mtime +$(BACKUP_RETENTION_DAYS) -print -delete
	@echo "Synced /project-zomboid-config/backups -> $(BACKUP_DIR)/ (keeping $(BACKUP_RETENTION_DAYS) days)"

VM_REPO_DIR := k3s-gameservers
## Copy every backup synced on the VM to this machine's data-backups/
##   Run it from your own machine, not the VM.
##   VM_HOST=user@host   the VM to reach over SSH, or set it in the root .env
download-backups:
	@mkdir -p $(BACKUP_DIR)
	$(MAKE) -C $(REPO_ROOT) copy-to-host \
		FILE=$(VM_REPO_DIR)/games/zomboid/$(BACKUP_DIR)/. DEST=$(BACKUP_DIR)

## Run make sync every hour with a systemd timer (on the k3s host; asks for sudo)
install-sync-timer:
	@test -d /run/systemd/system || { echo "systemd not found; run this on the k3s host" >&2; exit 1; }
	@sed -e "s|__REPO__|$(REPO_ROOT)|g" -e "s|__USER__|$$(id -un)|g" -e "s|__HOME__|$$HOME|g" \
		systemd/zomboid-data-sync.service | sudo tee /etc/systemd/system/zomboid-data-sync.service >/dev/null
	@sudo cp systemd/zomboid-data-sync.timer /etc/systemd/system/zomboid-data-sync.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now zomboid-data-sync.timer
	systemctl list-timers zomboid-data-sync.timer --no-pager

## Replace the live world with a backup from data-backups/, then start the server
##   Lists the backups, asks for a number, then asks you to type the game name to confirm.
##   Run make sync or make download-backups first.
restore-backup:
	@mapfile -t backups < <(find $(BACKUP_DIR) -name 'backup_*.zip' -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-); \
	test $${#backups[@]} -gt 0 || { echo "no backups in $(BACKUP_DIR)/ -- run 'make sync' or 'make download-backups' first" >&2; exit 1; }; \
	echo "Available backups (newest first):"; \
	for i in "$${!backups[@]}"; do \
		printf "  %2d) %-22s %s  %s\n" "$$((i + 1))" "$${backups[$$i]#$(BACKUP_DIR)/}" \
			"$$(date -r "$${backups[$$i]}" '+%Y-%m-%d %H:%M')" "$$(du -h "$${backups[$$i]}" | cut -f1)"; \
	done; \
	read -r -p "Select a backup to restore (number): " n; \
	idx=$$((n - 1)); \
	[ "$$idx" -ge 0 ] 2>/dev/null && [ "$$idx" -lt $${#backups[@]} ] || { echo "invalid selection" >&2; exit 1; }; \
	$(MAKE) _restore-run BACKUP="$${backups[$$idx]}"

# The zip holds Saves/Multiplayer/<name>, Server/, db/ and options.ini relative to
# /project-zomboid-config; only those are swapped, so Logs/ and backups/ stay put.
_restore-run:
	@test -n "$(BACKUP)" || { echo "usage: make _restore-run BACKUP=$(BACKUP_DIR)/<type>/backup_N.zip" >&2; exit 1; }
	@test -f "$(BACKUP)" || { echo "no such file: $(BACKUP)" >&2; exit 1; }
	@unzip -l "$(BACKUP)" | grep -q "Saves/Multiplayer/" || { echo "$(BACKUP) has no world save in it -- refusing" >&2; exit 1; }
	@echo "This REPLACES the live world of '$(RELEASE)' with $(BACKUP)."
	@read -r -p "Type $(RELEASE) to confirm: " a; [ "$$a" = "$(RELEASE)" ] || { echo "aborted" >&2; exit 1; }
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=0
	kubectl -n $(NAMESPACE) wait --for=delete pod/$(RELEASE)-0 --timeout=300s
	kubectl -n $(NAMESPACE) apply -f restore-helper-pod.yaml
	kubectl -n $(NAMESPACE) wait --for=condition=Ready pod/$(RELEASE)-restore-helper --timeout=180s
	kubectl -n $(NAMESPACE) cp "$(BACKUP)" $(RELEASE)-restore-helper:/tmp/restore.zip
	kubectl -n $(NAMESPACE) exec $(RELEASE)-restore-helper -- sh -c 'set -e; cd /data/config; \
		name=$$(unzip -p /tmp/restore.zip readme.txt | sed -n "s/^ServerName: *//p" | tr -d "\r"); \
		test -n "$$name"; keep=".replaced-$$(date +%Y%m%d-%H%M%S)"; \
		for p in "Saves/Multiplayer/$$name" Server db options.ini; do \
			[ -e "$$p" ] && mkdir -p "$$keep/$$(dirname "$$p")" && mv "$$p" "$$keep/$$p"; true; done; \
		unzip -q -o /tmp/restore.zip -x readme.txt; \
		echo "previous world kept at /project-zomboid-config/$$keep"'
	kubectl -n $(NAMESPACE) delete -f restore-helper-pod.yaml --wait
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=1
	@echo "Restored $(BACKUP). Watch it come up with: make logs"

## Forward localhost:9101 to the status-metrics /metrics endpoint
port-forward-metrics:
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE)-metrics 9101:9101

## Ship grafana/dashboards/ as a ConfigMap that Grafana loads
dashboards:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n $(NAMESPACE) create configmap $(RELEASE)-dashboards --from-file=grafana/dashboards/ --dry-run=client -o yaml \
		| kubectl label --local -f - grafana_dashboard=1 -o yaml \
		| kubectl annotate --local -f - grafana_folder=$(RELEASE) -o yaml \
		| kubectl apply --server-side -f -

## Remove the Helm release; the data volume is kept, delete it by hand to lose the world
uninstall:
	helm uninstall $(RELEASE) -n $(NAMESPACE)

include ../player-database.mk

include ../env.mk
include mods.mk
