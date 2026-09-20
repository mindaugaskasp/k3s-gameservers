SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
export KUBECONFIG ?= $(HOME)/.kube/config
CHART := ../../charts/zomboid-server
RELEASE := zomboid
NAMESPACE := games
VALUES := values.override.yaml
DATA_DIR := data
BACKUP_DIR := data-backups
REPO_ROOT := $(abspath ../..)
include ../metrics-image.mk
BACKUP_RETENTION_DAYS := 5

.PHONY: help lint template deploy status logs logs-metrics \
	restart scale-down-zero scale-up shell port-forward-metrics dashboards secrets-check \
	uninstall build-metrics-image push-metrics-image players backups announce \
	sync sync-data sync-backups install-sync-timer restore-backup _restore-run download-backups

help:
	@echo "make lint                  helm lint this chart+values"
	@echo "make template              render manifests locally (no cluster needed)"
	@echo "make build-metrics-image   podman build the status-metrics image"
	@echo "make push-metrics-image    build it and push to the in-cluster registry (no sudo)"
	@echo "make deploy                helm upgrade --install (needs ZOMBOID_ADMIN_PASSWORD and"
	@echo "                           ZOMBOID_RCON_PASSWORD; ZOMBOID_SERVER_PASSWORD, ZOMBOID_DISCORD_WEBHOOK,"
	@echo "                           ZOMBOID_CONNECT_HOST optional)"
	@echo "make status                pods/pvc/svc for this release"
	@echo "make logs                  tail the gameserver container"
	@echo "make logs-metrics          tail the status-metrics sidecar"
	@echo "make restart               rollout restart the statefulset (also how updates apply)"
	@echo "make scale-down-zero       scale the statefulset to 0 replicas"
	@echo "make scale-up              scale the statefulset back to 1 replica"
	@echo "make shell                 shell into the running gameserver container"
	@echo "make players               current player count from status-metrics"
	@echo "make announce MSG=\"...\"    broadcast an in-game message to all connected players via RCON"
	@echo "make backups               list the game's own period/startup/version backup zips"
	@echo "make sync                  pull config, install and backups into $(DATA_DIR)/ + $(BACKUP_DIR)/"
	@echo "make install-sync-timer    run that hourly via systemd (on the k3s host)"
	@echo "make download-backups      scp every synced backup to your machine's $(BACKUP_DIR)/"
	@echo "                           (run from your machine, not the VM; needs VM_HOST -- see root Makefile)"
	@echo "make restore-backup        pick a backup from a numbered list, restore it, start server again"
	@echo "make port-forward-metrics  forward :9101 to the status-metrics /metrics"
	@echo "make dashboards            ship grafana/dashboards/ as a ConfigMap Grafana picks up"
	@echo "make uninstall             helm uninstall (PVC is kept; delete it manually if you want data gone)"

lint:
	helm lint $(CHART) -f $(VALUES) --set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG)

template:
	helm template $(RELEASE) $(CHART) -f $(VALUES) -n $(NAMESPACE) \
		--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG) \
		--set-string secrets.adminPassword=REDACTED \
		--set-string secrets.rconPassword=REDACTED

secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$ZOMBOID_ADMIN_PASSWORD" || (echo "ZOMBOID_ADMIN_PASSWORD is not set" >&2; exit 1); \
	test -n "$$ZOMBOID_RCON_PASSWORD" || (echo "ZOMBOID_RCON_PASSWORD is not set" >&2; exit 1)

build-metrics-image:
	podman build --memory=512m -t $(STATUS_METRICS_IMAGE) $(STATUS_METRICS_DIR)

# Into the in-cluster registry k3s pulls from; the pod picks it up on its next start.
push-metrics-image: build-metrics-image
	podman push $(STATUS_METRICS_IMAGE)

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
		-f $(VALUES) \
		-n $(NAMESPACE) \
		--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG) \
		--set-string secrets.adminPassword="$$ZOMBOID_ADMIN_PASSWORD" \
		--set-string secrets.rconPassword="$$ZOMBOID_RCON_PASSWORD" \
		"$${extra[@]}"

status:
	kubectl -n $(NAMESPACE) get statefulset,pod,pvc,svc,cronjob -l app.kubernetes.io/instance=$(RELEASE)

logs:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c gameserver

logs-metrics:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c status-metrics

restart:
	kubectl -n $(NAMESPACE) rollout restart statefulset/$(RELEASE)

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
		sh -c 'cd /project-zomboid-config/backups && ls -la period startup version 2>/dev/null'

announce:
	@test -n "$(MSG)" || { echo "usage: make announce MSG=\"your message\"" >&2; exit 1; }
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- env MSG="$(MSG)" sh -c \
		'rcon -a 127.0.0.1:$${PORT_TCP_RCON:-27015} -p "$$RCON_PASSWORD" "servermsg \"$$MSG\""'

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
download-backups:
	@mkdir -p $(BACKUP_DIR)
	$(MAKE) -C $(REPO_ROOT) copy-to-host \
		FILE=$(VM_REPO_DIR)/games/zomboid/$(BACKUP_DIR)/. DEST=$(BACKUP_DIR)

install-sync-timer:
	@test -d /run/systemd/system || { echo "systemd not found; run this on the k3s host" >&2; exit 1; }
	@sed -e "s|__REPO__|$(REPO_ROOT)|g" -e "s|__USER__|$$(id -un)|g" -e "s|__HOME__|$$HOME|g" \
		systemd/zomboid-data-sync.service | sudo tee /etc/systemd/system/zomboid-data-sync.service >/dev/null
	@sudo cp systemd/zomboid-data-sync.timer /etc/systemd/system/zomboid-data-sync.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now zomboid-data-sync.timer
	systemctl list-timers zomboid-data-sync.timer --no-pager

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
