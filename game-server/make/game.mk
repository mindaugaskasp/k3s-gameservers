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

include $(GAME_SERVER_DIR)/make/world-data.mk
include $(GAME_SERVER_DIR)/make/player-database.mk
include $(GAME_SERVER_DIR)/make/env.mk
