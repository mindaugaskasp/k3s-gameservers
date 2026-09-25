SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
export KUBECONFIG ?= $(HOME)/.kube/config
CHART := ../../charts/enshrouded-server
RELEASE := enshrouded
NAMESPACE := games
VALUES := values.override.yaml
DATA_DIR := data
BACKUP_DIR := data-backups
REPO_ROOT := $(abspath ../..)
include ../metrics-image.mk
include ../../make/help.mk
BACKUP_RETENTION_DAYS := 5

.PHONY: help init-env lint template deploy status logs logs-metrics \
	restart scale-down-zero scale-up shell port-forward-metrics dashboards secrets-check \
	uninstall build-metrics-image push-metrics-image players backups backup-now force-update \
	sync sync-data sync-backups install-sync-timer restore-backup _restore-run download-backups


## Check the Helm chart and values.override.yaml with helm lint
lint:
	helm lint $(CHART) -f $(VALUES) --set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG)

## Render the manifests locally, with the password redacted; needs no cluster
template:
	helm template $(RELEASE) $(CHART) -f $(VALUES) -n $(NAMESPACE) \
		--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG) \
		--set-string secrets.rolePasswords.ADMIN_PASS=REDACTED

secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$ENSHROUDED_ADMIN_PASSWORD" || (echo "ENSHROUDED_ADMIN_PASSWORD is not set" >&2; exit 1)

## Build the status-metrics image with podman
build-metrics-image:
	podman build --memory=512m -t $(STATUS_METRICS_IMAGE) $(STATUS_METRICS_DIR)

# Into the in-cluster registry k3s pulls from; the pod picks it up on its next start.
## Build the status-metrics image and push it to the in-cluster registry
##   The pod picks it up on its next start.
push-metrics-image: build-metrics-image
	podman push $(STATUS_METRICS_IMAGE)

## Install or upgrade the Enshrouded server with Helm
##   Reads .env (see .env.example):
##   ENSHROUDED_ADMIN_PASSWORD   required
##   Server name, slots, chat, difficulty and the rest are optional .env overrides.
deploy: secrets-check
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
	helm upgrade --install $(RELEASE) $(CHART) \
		-f $(VALUES) \
		-n $(NAMESPACE) \
		--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG) \
		--set-string secrets.rolePasswords.ADMIN_PASS="$$ENSHROUDED_ADMIN_PASSWORD" \
		"$${extra[@]}"

## Show this game's StatefulSet, pod, volume and services
status:
	kubectl -n $(NAMESPACE) get statefulset,pod,pvc,svc -l app.kubernetes.io/instance=$(RELEASE)

## Follow the game server log
logs:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c gameserver

## Follow the status-metrics sidecar log
logs-metrics:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c status-metrics

## Restart the game server pod
restart:
	kubectl -n $(NAMESPACE) rollout restart statefulset/$(RELEASE)

## Run steamcmd now, even if the installed build looks current
force-update:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		supervisorctl start enshrouded-force-update

## Stop the game server by scaling it to 0 pods; its data is kept
scale-down-zero:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=0

## Start the game server again after scale-down-zero
scale-up:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=1

## Open a shell in the running game server container
shell:
	kubectl -n $(NAMESPACE) exec -it $(RELEASE)-0 -c gameserver -- bash

## Print the current player count from status-metrics
players:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c status-metrics -- \
		wget -qO- http://127.0.0.1:9101/metrics | grep game_server_players

## List the game's own backup zips
backups:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		sh -c 'ls -la /opt/enshrouded/backups 2>/dev/null'

## Take a game backup right now
backup-now:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		supervisorctl start enshrouded-backup

## Copy the save and backups from the pod into data/ and data-backups/
sync: sync-data sync-backups

# Skips server/, the steamcmd install the updater can always fetch again.
sync-data:
	@mkdir -p $(DATA_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C /opt/enshrouded --exclude=./server --exclude=./backups . | tar xf - -C $(DATA_DIR)
	@echo "Synced /opt/enshrouded -> $(DATA_DIR)/"

sync-backups:
	@mkdir -p $(BACKUP_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C /opt/enshrouded/backups . | tar xf - -C $(BACKUP_DIR)
	@find $(BACKUP_DIR) -type f -mtime +$(BACKUP_RETENTION_DAYS) -print -delete
	@echo "Synced /opt/enshrouded/backups -> $(BACKUP_DIR)/ (keeping $(BACKUP_RETENTION_DAYS) days)"

VM_REPO_DIR := k3s-gameservers
## Copy every backup synced on the VM to this machine's data-backups/
##   Run it from your own machine, not the VM.
##   VM_HOST=user@host   the VM to reach over SSH, or set it in the root .env
download-backups:
	@mkdir -p $(BACKUP_DIR)
	$(MAKE) -C $(REPO_ROOT) copy-to-host \
		FILE=$(VM_REPO_DIR)/games/enshrouded/$(BACKUP_DIR)/. DEST=$(BACKUP_DIR)

## Run make sync every hour with a systemd timer (on the k3s host; asks for sudo)
install-sync-timer:
	@test -d /run/systemd/system || { echo "systemd not found; run this on the k3s host" >&2; exit 1; }
	@sed -e "s|__REPO__|$(REPO_ROOT)|g" -e "s|__USER__|$$(id -un)|g" -e "s|__HOME__|$$HOME|g" \
		systemd/enshrouded-data-sync.service | sudo tee /etc/systemd/system/enshrouded-data-sync.service >/dev/null
	@sudo cp systemd/enshrouded-data-sync.timer /etc/systemd/system/enshrouded-data-sync.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now enshrouded-data-sync.timer
	systemctl list-timers enshrouded-data-sync.timer --no-pager

## Replace the live world with a backup from data-backups/, then start the server
##   Lists the backups, asks for a number, then asks you to type the game name to confirm.
##   Run make sync or make download-backups first.
restore-backup:
	@mapfile -t backups < <(find $(BACKUP_DIR) -name '*.zip' -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-); \
	test $${#backups[@]} -gt 0 || { echo "no backups in $(BACKUP_DIR)/ -- run 'make sync' or 'make download-backups' first" >&2; exit 1; }; \
	echo "Available backups (newest first):"; \
	for i in "$${!backups[@]}"; do \
		printf "  %2d) %-34s %s  %s\n" "$$((i + 1))" "$${backups[$$i]#$(BACKUP_DIR)/}" \
			"$$(date -r "$${backups[$$i]}" '+%Y-%m-%d %H:%M')" "$$(du -h "$${backups[$$i]}" | cut -f1)"; \
	done; \
	read -r -p "Select a backup to restore (number): " n; \
	idx=$$((n - 1)); \
	[ "$$idx" -ge 0 ] 2>/dev/null && [ "$$idx" -lt $${#backups[@]} ] || { echo "invalid selection" >&2; exit 1; }; \
	$(MAKE) _restore-run BACKUP="$${backups[$$idx]}"

# The zip holds the newest save file plus its index, both restored into
# savegame/. The game install and backups/ are left alone.
_restore-run:
	@test -n "$(BACKUP)" || { echo "usage: make _restore-run BACKUP=$(BACKUP_DIR)/<file>.zip" >&2; exit 1; }
	@test -f "$(BACKUP)" || { echo "no such file: $(BACKUP)" >&2; exit 1; }
	@unzip -l "$(BACKUP)" | grep -q -- "-index" || { echo "$(BACKUP) has no save index in it -- refusing" >&2; exit 1; }
	@echo "This REPLACES the live world of '$(RELEASE)' with $(BACKUP)."
	@read -r -p "Type $(RELEASE) to confirm: " a; [ "$$a" = "$(RELEASE)" ] || { echo "aborted" >&2; exit 1; }
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=0
	kubectl -n $(NAMESPACE) wait --for=delete pod/$(RELEASE)-0 --timeout=300s
	kubectl -n $(NAMESPACE) apply -f restore-helper-pod.yaml
	kubectl -n $(NAMESPACE) wait --for=condition=Ready pod/$(RELEASE)-restore-helper --timeout=180s
	kubectl -n $(NAMESPACE) cp "$(BACKUP)" $(RELEASE)-restore-helper:/tmp/restore.zip
	kubectl -n $(NAMESPACE) exec $(RELEASE)-restore-helper -- sh -c 'set -e; cd /data; \
		keep=".replaced-$$(date +%Y%m%d-%H%M%S)"; \
		[ -d savegame ] && mv savegame "$$keep"; \
		mkdir -p savegame; unzip -q -o /tmp/restore.zip -d savegame; \
		chown -R 4711:4711 savegame; \
		echo "previous world kept at /opt/enshrouded/$$keep"'
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

include ../env.mk
