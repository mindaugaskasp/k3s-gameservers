# What every game's Makefile shares. The game sets RELEASE (release and StatefulSet name), GAME_DATA_PATH
# and GAME_BACKUP_PATH (its data and backups inside the gameserver container), then includes this file
# first; optional variables and their defaults follow, and game-only targets come after the include.
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
# The game's backup files, and how to list what an archive holds.
BACKUP_FILE_PATTERN ?= *.zip
BACKUP_ARCHIVE_LIST_COMMAND ?= unzip -l
# A path every restorable archive holds; empty skips the check, e.g. for a bare world file.
RESTORE_REQUIRED_ARCHIVE_ENTRY ?=
# Dashboards from game-server/grafana/ shipped beside grafana/dashboards/, and the name they show.
SHARED_DASHBOARDS ?= process-health game-stats-logs
GAME_TITLE ?= $(RELEASE)
# Run after scale-down-zero and scale-up, e.g. to pause the game's own CronJobs.
AFTER_SCALE_DOWN_ZERO ?= true
AFTER_SCALE_UP ?= true

include $(GAME_SERVER_DIR)/make/metrics-image.mk
include $(REPO_ROOT)/make/help.mk

HELM_RELEASE_FLAGS = $(RELEASE) $(CHART) $(addprefix -f ,$(VALUE_FILES)) -n $(NAMESPACE) \
	--set-string statusMetrics.image.tag=$(STATUS_METRICS_TAG)
# --atomic rolls a failed release back by itself; 15m covers a first start's server download.
HELM_UPGRADE_FLAGS = $(HELM_RELEASE_FLAGS) --atomic --timeout 15m
# A deploy recipe's first line: loads .env and the helpers that turn it into helm_flags.
LOAD_ENV_FOR_HELM = set -a; [ -f .env ] && . ./.env; set +a; . $(GAME_SERVER_DIR)/make/helm-values-from-env.sh

.PHONY: help init-env lint template status logs logs-metrics restart scale-down-zero scale-up shell check-no-players \
	players backups sync sync-data sync-backups download-backups install-sync-timer restore-backup verify-offsite-backup \
	_restore-run start-volume-helper stop-volume-helper port-forward-metrics dashboards uninstall build-metrics-image push-metrics-image \
	read-player-db reset-player-stats chart-dependencies

# The shared library chart is copied into the game's chart/charts/ before any helm command.
chart-dependencies:
	@helm dependency update $(CHART) >/dev/null

# Everything that stops or replaces the running server first proves nobody is on it.
deploy restart scale-down-zero: check-no-players

# Refuses while players are online, or when the count is unreadable; FORCE=1 overrides.
check-no-players:
	@if [ "$(FORCE)" = "1" ]; then exit 0; fi; \
	kubectl -n $(NAMESPACE) get pod $(RELEASE)-0 >/dev/null 2>&1 || exit 0; \
	players=$$(kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c status-metrics -- \
		wget -qO- -T 5 http://127.0.0.1:9101/metrics 2>/dev/null \
		| awk '/^game_server_players[{ ]/{print int($$2); exit}'); \
	[ -n "$$players" ] || { echo "player count unreadable; stop the server first or re-run with FORCE=1" >&2; exit 1; }; \
	[ "$$players" -eq 0 ] || { echo "$$players player(s) online -- refusing; re-run with FORCE=1 to kick them" >&2; exit 1; }

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

## Forward localhost:9101 to the status-metrics /metrics endpoint
port-forward-metrics:
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE)-metrics 9101:9101

# The gamedig id, the metrics' game label; read from the chart, its one definition.
GAMEDIG_GAME = $(shell sed -n '/name: GAMEDIG_GAME/{n;s/.*value: "\(.*\)"/\1/p;}' $(CHART)/templates/_status-metrics.tpl)

## Ship grafana/dashboards/ and the shared ones as a ConfigMap that Grafana loads
dashboards:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@folder=$$(mktemp -d) && trap 'rm -rf "$$folder"' EXIT && { [ ! -d grafana/dashboards ] || cp grafana/dashboards/*.json "$$folder"/; } && \
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

include $(GAME_SERVER_DIR)/make/world-data.mk
include $(GAME_SERVER_DIR)/make/player-database.mk
include $(GAME_SERVER_DIR)/make/env.mk
