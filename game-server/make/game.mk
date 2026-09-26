# What every game's Makefile shares. The game sets these, then includes this file first:
#   RELEASE            Helm release, StatefulSet and label name, e.g. valheim
#   GAME_DATA_PATH     where the game keeps its data inside the gameserver container
#   GAME_BACKUP_PATH   where the game writes its backup archives inside the container
# Optional ones are listed with their defaults below. Game-only targets follow the include.
SHELL := /bin/bash
# pipefail so a failed `kubectl ... | tar` aborts before anything after it runs.
.SHELLFLAGS := -o pipefail -c
export KUBECONFIG ?= $(HOME)/.kube/config
NAMESPACE := games
REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../..)
GAME_FOLDER := $(notdir $(CURDIR))
GAME_SERVER_DIR := $(REPO_ROOT)/game-server
DATA_DIR := data
BACKUP_DIR := data-backups
# The game's Helm chart, and the values files every helm command reads, in order.
CHART ?= chart
VALUE_FILES ?= values.override.yaml
# Passed to `make template` so no real password is ever rendered.
TEMPLATE_SECRET_FLAGS ?=
GAME_SHELL ?= sh
STATUS_KINDS ?= statefulset,pod,pvc,svc
# Folders under GAME_DATA_PATH that `make sync-data` leaves out; backups have their own sync.
SYNC_DATA_EXCLUDES ?= backups
# Empty: data-backups/ mirrors the server's. A number: keeps what was synced for that many days.
BACKUP_SYNC_RETENTION_DAYS ?=
# A path every restorable backup zip holds; `make restore-backup` refuses a zip without it.
RESTORE_REQUIRED_ZIP_ENTRY ?=
# Dashboards from game-server/grafana/ shipped beside grafana/dashboards/, and the name they show.
SHARED_DASHBOARDS ?= process-health
GAME_TITLE ?= $(RELEASE)
# Run after scale-down-zero and scale-up, e.g. to pause the game's own CronJobs.
AFTER_SCALE_DOWN_ZERO ?= true
AFTER_SCALE_UP ?= true

include $(GAME_SERVER_DIR)/make/metrics-image.mk
include $(REPO_ROOT)/make/help.mk

HELM_RELEASE_FLAGS = $(RELEASE) $(CHART) $(addprefix -f ,$(VALUE_FILES)) -n $(NAMESPACE) \
	--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG)

.PHONY: help init-env lint template status logs logs-metrics restart scale-down-zero scale-up shell \
	players backups sync sync-data sync-backups download-backups install-sync-timer restore-backup \
	_restore-run start-volume-helper stop-volume-helper port-forward-metrics dashboards uninstall build-metrics-image push-metrics-image \
	read-player-db reset-player-stats chart-dependencies

# The shared library chart is copied into the game's chart/charts/ before any helm command.
chart-dependencies:
	@helm dependency update $(CHART) >/dev/null

## Check the Helm chart and values.override.yaml with helm lint
lint: chart-dependencies
	helm lint $(CHART) $(addprefix -f ,$(VALUE_FILES)) --set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG)

## Render the manifests locally, with the passwords redacted; needs no cluster
template: chart-dependencies
	helm template $(HELM_RELEASE_FLAGS) $(TEMPLATE_SECRET_FLAGS)

## Build the status-metrics image with podman
build-metrics-image:
	podman build --memory=512m $(STATUS_METRICS_BUILD_FLAGS) -t $(STATUS_METRICS_IMAGE) $(STATUS_METRICS_DIR)

## Build the status-metrics image and push it to the in-cluster registry
##   The pod picks it up on its next start.
push-metrics-image: build-metrics-image
	podman push $(STATUS_METRICS_IMAGE)

## Show this game's StatefulSet, pod, volume and services
status:
	kubectl -n $(NAMESPACE) get $(STATUS_KINDS) -l app.kubernetes.io/instance=$(RELEASE)

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
	@$(AFTER_SCALE_DOWN_ZERO)

## Start the game server again after scale-down-zero
scale-up:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=1
	@$(AFTER_SCALE_UP)

## Open a shell in the running game server container
shell:
	kubectl -n $(NAMESPACE) exec -it $(RELEASE)-0 -c gameserver -- $(GAME_SHELL)

## Print the current player count from status-metrics
players:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c status-metrics -- \
		wget -qO- http://127.0.0.1:9101/metrics | grep game_server_players

## List the game's own backup archives
backups:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- ls -laR $(GAME_BACKUP_PATH)

# Read-only pulls from the running pod; restore-backup is the only path that writes back.
## Copy the world, config and backups from the pod into data/ and data-backups/
sync: sync-data sync-backups

sync-data:
	@mkdir -p $(DATA_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C $(GAME_DATA_PATH) $(foreach folder,$(SYNC_DATA_EXCLUDES),--exclude=./$(folder)) . \
		| tar xf - -C $(DATA_DIR)
	@echo "Synced $(GAME_DATA_PATH) -> $(DATA_DIR)/"

# A mirror is swapped in only once complete and only if the server still has backups,
# so a failed pull keeps the old copy.
sync-backups:
ifeq ($(BACKUP_SYNC_RETENTION_DAYS),)
	@rm -rf $(BACKUP_DIR).new && mkdir -p $(BACKUP_DIR).new
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C $(GAME_BACKUP_PATH) . | tar xf - -C $(BACKUP_DIR).new
	@ls $(BACKUP_DIR).new/*.zip >/dev/null 2>&1 || { \
		echo "server has no backups; keeping $(BACKUP_DIR)/ unchanged" >&2; rm -rf $(BACKUP_DIR).new; exit 1; }
	@rm -rf $(BACKUP_DIR).old; if [ -d $(BACKUP_DIR) ]; then mv $(BACKUP_DIR) $(BACKUP_DIR).old; fi
	@mv $(BACKUP_DIR).new $(BACKUP_DIR) && rm -rf $(BACKUP_DIR).old
	@echo "Synced $(GAME_BACKUP_PATH) -> $(BACKUP_DIR)/"
else
	@mkdir -p $(BACKUP_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C $(GAME_BACKUP_PATH) . | tar xf - -C $(BACKUP_DIR)
	@find $(BACKUP_DIR) -type f -mtime +$(BACKUP_SYNC_RETENTION_DAYS) -print -delete
	@echo "Synced $(GAME_BACKUP_PATH) -> $(BACKUP_DIR)/ (keeping $(BACKUP_SYNC_RETENTION_DAYS) days)"
endif

VM_REPO_DIR := k3s-gameservers
## Copy every backup synced on the VM to this machine's data-backups/
##   Run it from your own machine, not the VM.
##   VM_HOST=user@host   the VM to reach over SSH, or set it in the root .env
download-backups:
	@mkdir -p $(BACKUP_DIR)
	$(MAKE) -C $(REPO_ROOT) copy-to-host \
		FILE=$(VM_REPO_DIR)/games/$(GAME_FOLDER)/$(BACKUP_DIR)/. DEST=$(BACKUP_DIR)

## Run make sync every hour with a systemd timer (on the k3s host; asks for sudo)
install-sync-timer:
	@test -d /run/systemd/system || { echo "systemd not found; run this on the k3s host" >&2; exit 1; }
	@sed -e "s|__REPO__|$(REPO_ROOT)|g" -e "s|__USER__|$$(id -un)|g" -e "s|__HOME__|$$HOME|g" \
		$(GAME_SERVER_DIR)/systemd/game-data-sync@.service | sudo tee /etc/systemd/system/game-data-sync@.service >/dev/null
	@sudo cp $(GAME_SERVER_DIR)/systemd/game-data-sync@.timer /etc/systemd/system/game-data-sync@.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now game-data-sync@$(GAME_FOLDER).timer
	systemctl list-timers game-data-sync@$(GAME_FOLDER).timer --no-pager

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

RESTORE_HELPER_POD = sed 's/__RELEASE__/$(RELEASE)/g' $(GAME_SERVER_DIR)/restore-helper-pod.yaml

## Stop the game and start a helper pod with its volume at /data, to edit files by hand
##   make stop-volume-helper removes it; then make scale-up starts the game.
start-volume-helper:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=0
	kubectl -n $(NAMESPACE) wait --for=delete pod/$(RELEASE)-0 --timeout=300s
	$(RESTORE_HELPER_POD) | kubectl -n $(NAMESPACE) apply -f -
	kubectl -n $(NAMESPACE) wait --for=condition=Ready pod/$(RELEASE)-restore-helper --timeout=180s

## Remove the helper pod start-volume-helper started
stop-volume-helper:
	$(RESTORE_HELPER_POD) | kubectl -n $(NAMESPACE) delete --wait -f -

# The game's restore-backup.sh unpacks the zip over the volume, inside the helper pod.
_restore-run:
	@test -n "$(BACKUP)" || { echo "usage: make _restore-run BACKUP=$(BACKUP_DIR)/<file>.zip" >&2; exit 1; }
	@test -f "$(BACKUP)" || { echo "no such file: $(BACKUP)" >&2; exit 1; }
	@unzip -l "$(BACKUP)" | grep -q -- "$(RESTORE_REQUIRED_ZIP_ENTRY)" \
		|| { echo "$(BACKUP) has no $(RESTORE_REQUIRED_ZIP_ENTRY) in it -- refusing" >&2; exit 1; }
	@echo "This REPLACES the live world of '$(RELEASE)' with $(BACKUP)."
	@read -r -p "Type $(RELEASE) to confirm: " a; [ "$$a" = "$(RELEASE)" ] || { echo "aborted" >&2; exit 1; }
	@$(MAKE) --no-print-directory start-volume-helper
	kubectl -n $(NAMESPACE) cp "$(BACKUP)" $(RELEASE)-restore-helper:/tmp/restore.zip
	kubectl -n $(NAMESPACE) exec -i $(RELEASE)-restore-helper -- sh < restore-backup.sh
	@$(MAKE) --no-print-directory stop-volume-helper
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=1
	@echo "Restored $(BACKUP). Watch it come up with: make logs"

## Forward localhost:9101 to the status-metrics /metrics endpoint
port-forward-metrics:
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE)-metrics 9101:9101

# The gamedig id, the metrics' game label; read from the chart, its one definition.
GAMEDIG_GAME = $(shell sed -n '/name: GAMEDIG_GAME/{n;s/.*value: "\(.*\)"/\1/p;}' $(CHART)/templates/_status-metrics.tpl)

## Ship grafana/dashboards/ and the shared ones as a ConfigMap that Grafana loads
dashboards:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@folder=$$(mktemp -d) && trap 'rm -rf "$$folder"' EXIT && cp grafana/dashboards/*.json "$$folder"/ && \
	for dashboard in $(SHARED_DASHBOARDS); do \
		sed -e 's/__GAME_TITLE__/$(GAME_TITLE)/g' -e 's/__RELEASE__/$(RELEASE)/g' -e 's/__GAMEDIG_GAME__/$(GAMEDIG_GAME)/g' \
			$(GAME_SERVER_DIR)/grafana/$$dashboard.json > "$$folder/$$dashboard.json"; \
	done && \
	kubectl -n $(NAMESPACE) create configmap $(RELEASE)-dashboards --from-file="$$folder"/ --dry-run=client -o yaml \
		| kubectl label --local -f - grafana_dashboard=1 -o yaml \
		| kubectl annotate --local -f - grafana_folder=$(RELEASE) -o yaml \
		| kubectl apply --server-side -f -

## Remove the Helm release; the data volume is kept, delete it by hand to lose the world
uninstall:
	helm uninstall $(RELEASE) -n $(NAMESPACE)

include $(GAME_SERVER_DIR)/make/player-database.mk
include $(GAME_SERVER_DIR)/make/env.mk
