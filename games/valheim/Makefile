SHELL := /bin/bash
# pipefail so a failed `kubectl ... | tar` aborts before the backup prune runs.
.SHELLFLAGS := -o pipefail -c
export KUBECONFIG ?= $(HOME)/.kube/config
CHART := ../../charts/valheim-server
RELEASE := valheim
NAMESPACE := games
VALUES := values.override.yaml
DATA_DIR := data
BACKUP_DIR := data-backups
REPO_ROOT := $(abspath ../..)
include ../metrics-image.mk
include ../../make/help.mk

.PHONY: help init-env lint template deploy status logs logs-metrics \
	restart scale-down-zero scale-up shell port-forward-metrics dashboards secrets-check \
	uninstall build-metrics-image push-metrics-image players backups \
	sync sync-data sync-backups install-sync-timer restore-backup _restore-run \
	mods-status approve-mods download-backups read-player-db reset-player-stats


## Check the Helm chart and values.override.yaml with helm lint
lint:
	helm lint $(CHART) -f $(VALUES) --set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG)

## Render the manifests locally, with the password redacted; needs no cluster
template:
	helm template $(RELEASE) $(CHART) -f $(VALUES) -n $(NAMESPACE) \
		--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG) \
		--set-string secrets.serverPassword=REDACTED

# Secrets come from the environment or a gitignored .env here; see .env.example.
secrets-check:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	test -n "$$VALHEIM_SERVER_PASSWORD" || (echo "VALHEIM_SERVER_PASSWORD is not set (env or .env)" >&2; exit 1)

## Build the status-metrics image with podman
build-metrics-image:
	podman build --memory=512m $(STATUS_METRICS_BUILD_FLAGS) -t $(STATUS_METRICS_IMAGE) $(STATUS_METRICS_DIR)

# Into the in-cluster registry k3s pulls from; the pod picks it up on its next start.
## Build the status-metrics image and push it to the in-cluster registry
##   The pod picks it up on its next start.
push-metrics-image: build-metrics-image
	podman push $(STATUS_METRICS_IMAGE)

# Discord alerts stay off unless VALHEIM_DISCORD_WEBHOOK is exported.
# connectHost is set the same way, via VALHEIM_CONNECT_HOST, so the public
# DDNS hostname never has to be committed to values.override.yaml.
## Install or upgrade the Valheim server with Helm
##   Reads .env (see .env.example):
##   VALHEIM_SERVER_PASSWORD   required, the password players join with
##   VALHEIM_DISCORD_WEBHOOK   optional, turns on Discord alerts
##   VALHEIM_CONNECT_HOST      optional, the public host name shown to players
deploy: secrets-check
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@set -a; [ -f .env ] && . ./.env; set +a; \
	extra=(); \
	if [ -n "$$VALHEIM_DISCORD_WEBHOOK" ]; then \
		extra+=(--set alerts.enabled=true \
			--set-string alerts.discordWebhook="$$VALHEIM_DISCORD_WEBHOOK"); \
	else \
		echo "note: VALHEIM_DISCORD_WEBHOOK unset, deploying without Discord alerts" >&2; \
	fi; \
	if [ -n "$$VALHEIM_CONNECT_HOST" ]; then \
		extra+=(--set-string server.connectHost="$$VALHEIM_CONNECT_HOST"); \
	fi; \
	helm upgrade --install $(RELEASE) $(CHART) \
		-f $(VALUES) \
		-n $(NAMESPACE) \
		--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG) \
		--set-string secrets.serverPassword="$$VALHEIM_SERVER_PASSWORD" \
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

## Stop the game server by scaling it to 0 pods; its data is kept
scale-down-zero:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=0

## Start the game server again after scale-down-zero
scale-up:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=1

## Open a shell in the running game server container
shell:
	kubectl -n $(NAMESPACE) exec -it $(RELEASE)-0 -c gameserver -- sh

## Print the current player count from status-metrics
players:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c status-metrics -- \
		wget -qO- http://127.0.0.1:9101/metrics | grep game_server_players

## List the backups under /config/backups
backups:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- ls -laR /config/backups

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

# Read-only pull from the running pod. `restore` is the only path that
# writes back, and it stops the server first.
## Copy the world, config and backups from the pod into data/ and data-backups/
sync: sync-data sync-backups

sync-data:
	@mkdir -p $(DATA_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C /config --exclude=./backups . | tar xf - -C $(DATA_DIR)
	@echo "Synced /config (worlds + config) -> $(DATA_DIR)/"

# Mirrors the server's backups + archive, swapped in only once complete and
# only if the server still has backups, so a failed pull keeps the old copy.
sync-backups:
	@rm -rf $(BACKUP_DIR).new && mkdir -p $(BACKUP_DIR).new
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C /config/backups . | tar xf - -C $(BACKUP_DIR).new
	@ls $(BACKUP_DIR).new/*.zip >/dev/null 2>&1 || { \
		echo "server has no backups; keeping $(BACKUP_DIR)/ unchanged" >&2; rm -rf $(BACKUP_DIR).new; exit 1; }
	@rm -rf $(BACKUP_DIR).old; if [ -d $(BACKUP_DIR) ]; then mv $(BACKUP_DIR) $(BACKUP_DIR).old; fi
	@mv $(BACKUP_DIR).new $(BACKUP_DIR) && rm -rf $(BACKUP_DIR).old
	@echo "Synced /config/backups -> $(BACKUP_DIR)/"

# Run from your own machine (needs VM_HOST): pulls every backup synced on the VM.
VM_REPO_DIR := k3s-gameservers
## Copy every backup synced on the VM to this machine's data-backups/
##   Run it from your own machine, not the VM.
##   VM_HOST=user@host   the VM to reach over SSH, or set it in the root .env
download-backups:
	@mkdir -p $(BACKUP_DIR)
	$(MAKE) -C $(REPO_ROOT) copy-to-host \
		FILE=$(VM_REPO_DIR)/games/valheim/$(BACKUP_DIR)/. DEST=$(BACKUP_DIR)

## Run make sync every hour with a systemd timer (on the k3s host; asks for sudo)
install-sync-timer:
	@test -d /run/systemd/system || { echo "systemd not found; run this on the k3s host" >&2; exit 1; }
	@sed -e "s|__REPO__|$(REPO_ROOT)|g" -e "s|__USER__|$$(id -un)|g" -e "s|__HOME__|$$HOME|g" \
		systemd/valheim-data-sync.service | sudo tee /etc/systemd/system/valheim-data-sync.service >/dev/null
	@sudo cp systemd/valheim-data-sync.timer /etc/systemd/system/valheim-data-sync.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now valheim-data-sync.timer
	systemctl list-timers valheim-data-sync.timer --no-pager

# Overwrites the live world. Stops the server, unpacks the archive over the
# PVC via a helper pod, then starts it again.
## Replace the live world with a backup from data-backups/, then start the server
##   Lists the backups, asks for a number, then asks you to type the game name to confirm.
##   Run make sync or make download-backups first.
restore-backup:
	@mapfile -t backups < <(cd $(BACKUP_DIR) 2>/dev/null && ls -1t *.zip archive/*.zip 2>/dev/null); \
	test $${#backups[@]} -gt 0 || { echo "no backups in $(BACKUP_DIR)/ -- run 'make sync' or 'make download-backups' first" >&2; exit 1; }; \
	echo "Available backups (newest first):"; \
	for i in "$${!backups[@]}"; do printf "  %2d) %s\n" "$$((i + 1))" "$${backups[$$i]}"; done; \
	read -r -p "Select a backup to restore (number): " n; \
	idx=$$((n - 1)); \
	[ "$$idx" -ge 0 ] 2>/dev/null && [ "$$idx" -lt $${#backups[@]} ] || { echo "invalid selection" >&2; exit 1; }; \
	$(MAKE) _restore-run BACKUP=$(BACKUP_DIR)/$${backups[$$idx]}

_restore-run:
	@test -n "$(BACKUP)" || { echo "usage: make _restore-run BACKUP=$(BACKUP_DIR)/<file>.zip" >&2; exit 1; }
	@test -f "$(BACKUP)" || { echo "no such file: $(BACKUP)" >&2; exit 1; }
	@echo "This REPLACES the live world of '$(RELEASE)' with $(BACKUP)."
	@read -r -p "Type $(RELEASE) to confirm: " a; [ "$$a" = "$(RELEASE)" ] || { echo "aborted" >&2; exit 1; }
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=0
	kubectl -n $(NAMESPACE) wait --for=delete pod/$(RELEASE)-0 --timeout=300s
	kubectl -n $(NAMESPACE) apply -f restore-helper-pod.yaml
	kubectl -n $(NAMESPACE) wait --for=condition=Ready pod/$(RELEASE)-restore-helper --timeout=180s
	kubectl -n $(NAMESPACE) cp "$(BACKUP)" $(RELEASE)-restore-helper:/tmp/restore.zip
	@echo "Archive paths are config/worlds_local/..., so it unpacks at the PVC root."
	kubectl -n $(NAMESPACE) exec $(RELEASE)-restore-helper -- sh -c 'set -e; \
		cd /data; \
		rm -rf .restore-tmp; mkdir -p .restore-tmp; \
		unzip -q -o /tmp/restore.zip -d .restore-tmp; \
		test -d .restore-tmp/config/worlds_local; \
		ts=$$(date +%Y%m%d-%H%M%S); \
		if [ -d config/worlds_local ]; then mv config/worlds_local config/worlds_local.replaced-$$ts; fi; \
		mv .restore-tmp/config/worlds_local config/worlds_local; \
		rm -rf .restore-tmp; \
		echo "previous world kept at config/worlds_local.replaced-$$ts"'
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
