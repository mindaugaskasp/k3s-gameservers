SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
export KUBECONFIG ?= $(HOME)/.kube/config
CHART := ../../charts/enshrouded-server
STATUS_METRICS_DIR := ../../game-status-metrics
STATUS_METRICS_IMAGE := localhost:30500/k3s-gameservers/game-status-metrics:latest
RELEASE := enshrouded
NAMESPACE := games
VALUES := values.override.yaml
DATA_DIR := data
BACKUP_DIR := data-backups
REPO_ROOT := $(abspath ../..)
BACKUP_RETENTION_DAYS := 5

.PHONY: help lint template deploy status logs logs-metrics \
	restart scale-down-zero scale-up shell port-forward-metrics dashboards secrets-check \
	uninstall build-metrics-image push-metrics-image players backups backup-now force-update \
	sync sync-data sync-backups install-sync-timer restore-backup _restore-run download-backups

help:
	@echo "make lint                  helm lint this chart+values"
	@echo "make template              render manifests locally (no cluster needed)"
	@echo "make build-metrics-image   podman build the status-metrics image"
	@echo "make push-metrics-image    build it and push to the in-cluster registry (no sudo)"
	@echo "make deploy                helm upgrade --install (needs ENSHROUDED_ADMIN_PASSWORD; server"
	@echo "                           name, slots, chat, difficulty and the rest are optional .env"
	@echo "                           overrides -- see .env.example)"
	@echo "make status                pods/pvc/svc for this release"
	@echo "make logs                  tail the gameserver container"
	@echo "make logs-metrics          tail the status-metrics sidecar"
	@echo "make restart               rollout restart the statefulset"
	@echo "make force-update          re-run steamcmd now, even if the build looks current"
	@echo "make scale-down-zero       scale the statefulset to 0 replicas"
	@echo "make scale-up              scale the statefulset back to 1 replica"
	@echo "make shell                 shell into the running gameserver container"
	@echo "make players               current player count from status-metrics"
	@echo "make backups               list the game's own backup zips"
	@echo "make backup-now            take a backup right now"
	@echo "make sync                  pull the save and backups into $(DATA_DIR)/ + $(BACKUP_DIR)/"
	@echo "make install-sync-timer    run that hourly via systemd (on the k3s host)"
	@echo "make download-backups      scp every synced backup to your machine's $(BACKUP_DIR)/"
	@echo "                           (run from your machine, not the VM; needs VM_HOST -- see root Makefile)"
	@echo "make restore-backup        pick a backup from a numbered list, restore it, start server again"
	@echo "make port-forward-metrics  forward :9101 to the status-metrics /metrics"
	@echo "make dashboards            ship grafana/dashboards/ as a ConfigMap Grafana picks up"
	@echo "make uninstall             helm uninstall (PVC is kept; delete it manually if you want data gone)"

lint:
	helm lint $(CHART) -f $(VALUES)

template:
	helm template $(RELEASE) $(CHART) -f $(VALUES) -n $(NAMESPACE) \
		--set-string secrets.rolePasswords.ADMIN_PASS=REDACTED

secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$ENSHROUDED_ADMIN_PASSWORD" || (echo "ENSHROUDED_ADMIN_PASSWORD is not set" >&2; exit 1)

build-metrics-image:
	podman build --memory=512m -t $(STATUS_METRICS_IMAGE) $(STATUS_METRICS_DIR)

# Into the in-cluster registry k3s pulls from; the pod picks it up on its next start.
push-metrics-image: build-metrics-image
	podman push $(STATUS_METRICS_IMAGE)

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
		--set-string secrets.rolePasswords.ADMIN_PASS="$$ENSHROUDED_ADMIN_PASSWORD" \
		"$${extra[@]}"

status:
	kubectl -n $(NAMESPACE) get statefulset,pod,pvc,svc -l app.kubernetes.io/instance=$(RELEASE)

logs:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c gameserver

logs-metrics:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c status-metrics

restart:
	kubectl -n $(NAMESPACE) rollout restart statefulset/$(RELEASE)

force-update:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		supervisorctl start enshrouded-force-update

scale-down-zero:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=0

scale-up:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=1

shell:
	kubectl -n $(NAMESPACE) exec -it $(RELEASE)-0 -c gameserver -- bash

players:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c status-metrics -- \
		wget -qO- http://127.0.0.1:9101/metrics | grep game_server_players

backups:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		sh -c 'ls -la /opt/enshrouded/backups 2>/dev/null'

backup-now:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		supervisorctl start enshrouded-backup

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
download-backups:
	@mkdir -p $(BACKUP_DIR)
	$(MAKE) -C $(REPO_ROOT) copy-to-host \
		FILE=$(VM_REPO_DIR)/games/enshrouded/$(BACKUP_DIR)/. DEST=$(BACKUP_DIR)

install-sync-timer:
	@test -d /run/systemd/system || { echo "systemd not found; run this on the k3s host" >&2; exit 1; }
	@sed -e "s|__REPO__|$(REPO_ROOT)|g" -e "s|__USER__|$$(id -un)|g" -e "s|__HOME__|$$HOME|g" \
		systemd/enshrouded-data-sync.service | sudo tee /etc/systemd/system/enshrouded-data-sync.service >/dev/null
	@sudo cp systemd/enshrouded-data-sync.timer /etc/systemd/system/enshrouded-data-sync.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now enshrouded-data-sync.timer
	systemctl list-timers enshrouded-data-sync.timer --no-pager

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

port-forward-metrics:
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE)-metrics 9101:9101

dashboards:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n $(NAMESPACE) create configmap $(RELEASE)-dashboards --from-file=grafana/dashboards/ --dry-run=client -o yaml \
		| kubectl label --local -f - grafana_dashboard=1 -o yaml \
		| kubectl annotate --local -f - grafana_folder=$(RELEASE) -o yaml \
		| kubectl apply --server-side -f -

uninstall:
	helm uninstall $(RELEASE) -n $(NAMESPACE)
