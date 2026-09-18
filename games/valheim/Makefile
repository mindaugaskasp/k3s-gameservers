SHELL := /bin/bash
# pipefail so a failed `kubectl ... | tar` aborts before the backup prune runs.
.SHELLFLAGS := -o pipefail -c
CHART := ../../charts/valheim-server
STATUS_METRICS_DIR := ../../game-status-metrics
STATUS_METRICS_IMAGE := k3s-gameservers/game-status-metrics:latest
RELEASE := valheim
NAMESPACE := games
VALUES := values.override.yaml
DATA_DIR := data
BACKUP_DIR := data-backups
REPO_ROOT := $(abspath ../..)
# Keep this in step with backups.maxAge in the chart values.
BACKUP_RETENTION_DAYS := 5

.PHONY: help lint template deploy status logs logs-metrics \
	restart shell port-forward-metrics dashboards secrets-check \
	uninstall build-metrics-image import-metrics-image players backups \
	sync sync-data sync-backups install-sync-timer restore \
	mods-status approve-mods

help:
	@echo "make lint                  helm lint this chart+values"
	@echo "make template              render manifests locally (no cluster needed)"
	@echo "make build-metrics-image   podman build the status-metrics image"
	@echo "make import-metrics-image  load that image into k3s's containerd (needs sudo)"
	@echo "make deploy                helm upgrade --install (needs VALHEIM_SERVER_PASSWORD;"
	@echo "                           set VALHEIM_DISCORD_WEBHOOK too for alerts)"
	@echo "make status                pods/pvc/svc for this release"
	@echo "make logs                  tail the gameserver container"
	@echo "make logs-metrics          tail the status-metrics sidecar"
	@echo "make restart               rollout restart the statefulset"
	@echo "make shell                 shell into the running gameserver container"
	@echo "make players               current player count from status-metrics"
	@echo "make backups               list backups under /config/backups"
	@echo "make sync                  pull world, config and backups into $(DATA_DIR)/ + $(BACKUP_DIR)/"
	@echo "make install-sync-timer    run that sync hourly via systemd (on the k3s host)"
	@echo "make restore BACKUP=<f>    stop server, restore a backup archive, start it again"
	@echo "make mods-status           whether mods loaded, why not, and which plugins exist"
	@echo "make approve-mods          confirm mods work on the running game build,"
	@echo "                           so the fail-safe stops holding them back"
	@echo "make port-forward-metrics  forward :9101 to the status-metrics /metrics"
	@echo "make dashboards            push dashboards/*.json to Grafana (needs GRAFANA_TOKEN, GRAFANA_URL)"
	@echo "make uninstall             helm uninstall (PVC is kept; delete it manually if you want data gone)"

lint:
	helm lint $(CHART) -f $(VALUES)

template:
	helm template $(RELEASE) $(CHART) -f $(VALUES) -n $(NAMESPACE) \
		--set-string secrets.serverPassword=REDACTED

secrets-check:
	@test -n "$$VALHEIM_SERVER_PASSWORD" || (echo "VALHEIM_SERVER_PASSWORD is not set" >&2; exit 1)

build-metrics-image:
	podman build -t $(STATUS_METRICS_IMAGE) $(STATUS_METRICS_DIR)

# k3s reads from containerd, not podman's store, so the image is handed
# over as an OCI archive rather than pushed to a registry.
import-metrics-image: build-metrics-image
	podman save --format oci-archive $(STATUS_METRICS_IMAGE) | sudo k3s ctr images import -

# Discord alerts stay off unless VALHEIM_DISCORD_WEBHOOK is exported.
deploy: secrets-check
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@extra=(); \
	if [ -n "$$VALHEIM_DISCORD_WEBHOOK" ]; then \
		extra+=(--set alerts.enabled=true \
			--set-string alerts.discordWebhook="$$VALHEIM_DISCORD_WEBHOOK"); \
	else \
		echo "note: VALHEIM_DISCORD_WEBHOOK unset, deploying without Discord alerts" >&2; \
	fi; \
	helm upgrade --install $(RELEASE) $(CHART) \
		-f $(VALUES) \
		-n $(NAMESPACE) \
		--set-string secrets.serverPassword="$$VALHEIM_SERVER_PASSWORD" \
		"$${extra[@]}"

status:
	kubectl -n $(NAMESPACE) get statefulset,pod,pvc,svc -l app.kubernetes.io/instance=$(RELEASE)

logs:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c gameserver

logs-metrics:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c status-metrics

restart:
	kubectl -n $(NAMESPACE) rollout restart statefulset/$(RELEASE)

shell:
	kubectl -n $(NAMESPACE) exec -it $(RELEASE)-0 -c gameserver -- sh

players:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c status-metrics -- \
		wget -qO- http://127.0.0.1:9101/metrics | grep game_server_players

backups:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- ls -la /config/backups

mods-status:
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- sh -c '\
		printf "mods active: "; cat /var/run/valheim-status/mods-active 2>/dev/null || echo "(fail-safe not in use)"; \
		printf "reason:      "; cat /var/run/valheim-status/mods-status 2>/dev/null; echo; \
		printf "approved build: "; cat /config/mods-approved-build 2>/dev/null || echo "(none)"; echo; \
		printf "plugins:     "; ls -1 /config/bepinex/plugins 2>/dev/null | tr "\n" " " || echo "(none)"; echo'

# Records YOUR confirmation that mods work on this build; it tests nothing.
approve-mods:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- /etc/valheim-hooks/approve-mods.sh
	@echo "Restart to load mods: make restart"

# Read-only pull from the running pod. `restore` is the only path that
# writes back, and it stops the server first.
sync: sync-data sync-backups

sync-data:
	@mkdir -p $(DATA_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C /config --exclude=./backups . | tar xf - -C $(DATA_DIR)
	@echo "Synced /config (worlds + config) -> $(DATA_DIR)/"

# Local copies are pruned to the same window the server keeps.
sync-backups:
	@mkdir -p $(BACKUP_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C /config/backups . | tar xf - -C $(BACKUP_DIR)
	@find $(BACKUP_DIR) -type f -mtime +$(BACKUP_RETENTION_DAYS) -print -delete
	@echo "Synced /config/backups -> $(BACKUP_DIR)/ (keeping $(BACKUP_RETENTION_DAYS) days)"

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
restore:
	@test -n "$(BACKUP)" || { echo "usage: make restore BACKUP=$(BACKUP_DIR)/<file>.zip" >&2; \
		echo "available:" >&2; ls -1t $(BACKUP_DIR) 2>/dev/null | head -20 >&2; exit 1; }
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

port-forward-metrics:
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE)-metrics 9101:9101

# Targets the Grafana on the webserver VM; a "valheim" folder must exist there.
dashboards:
	@test -n "$$GRAFANA_TOKEN" || (echo "GRAFANA_TOKEN is not set" >&2; exit 1)
	@test -n "$$GRAFANA_URL" || (echo "GRAFANA_URL is not set" >&2; exit 1)
	@for f in dashboards/*.json; do \
		python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps({'dashboard': d, 'folderUid': 'valheim', 'overwrite': True}))" "$$f" \
		| curl -sf -X POST "$$GRAFANA_URL/api/dashboards/db" \
			-H "Authorization: Bearer $$GRAFANA_TOKEN" -H "Content-Type: application/json" -d @- ; \
		echo ; \
	done

uninstall:
	helm uninstall $(RELEASE) -n $(NAMESPACE)
