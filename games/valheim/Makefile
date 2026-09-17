# Uses charts/valheim-server, not charts/linuxgsm-game -- see docs/architecture.md.
# Export VALHEIM_SERVER_PASSWORD in your shell before `make deploy`.

SHELL := /bin/bash
CHART := ../../charts/valheim-server
RELEASE := valheim
NAMESPACE := games
VALUES := values.yaml
EXPORTER_DIR := ../../monitoring/exporter
EXPORTER_IMAGE := k3s-linuxgsm/lgsm-exporter:latest

.PHONY: help lint template deploy status logs logs-exporter \
	restart shell port-forward-metrics port-forward-game \
	dashboards secrets-check uninstall build-exporter import-exporter \
	players backups

help:
	@echo "make lint                  helm lint this chart+values"
	@echo "make template              render manifests locally (no cluster access needed)"
	@echo "make build-exporter        podman build the metrics exporter image"
	@echo "make import-exporter       import the exporter image into k3s's containerd (needs sudo)"
	@echo "make deploy                helm upgrade --install (requires VALHEIM_SERVER_PASSWORD)"
	@echo "make status                pods/pvc/svc for this release"
	@echo "make logs                  tail the gameserver container"
	@echo "make logs-exporter         tail the metrics-exporter sidecar"
	@echo "make restart               rollout restart the statefulset"
	@echo "make shell                 shell into the running gameserver container"
	@echo "make players               current player count from the exporter"
	@echo "make backups               list backups under /config/backups in the running pod"
	@echo "make port-forward-metrics  forward :9101 to the exporter's /metrics"
	@echo "make port-forward-game     forward :2456-2458 udp is not supported by kubectl port-forward; use NodePort instead (see status)"
	@echo "make dashboards            push both dashboard JSONs to Grafana (requires GRAFANA_TOKEN, GRAFANA_URL)"
	@echo "make uninstall             helm uninstall this release (PVC is kept; delete manually if you want data gone)"

lint:
	helm lint $(CHART) -f $(VALUES)

template:
	helm template $(RELEASE) $(CHART) -f $(VALUES) -n $(NAMESPACE) \
		--set-string secrets.serverPassword=REDACTED

secrets-check:
	@test -n "$$VALHEIM_SERVER_PASSWORD" || (echo "VALHEIM_SERVER_PASSWORD is not set" >&2; exit 1)

build-exporter:
	podman build -t $(EXPORTER_IMAGE) $(EXPORTER_DIR)

import-exporter: build-exporter
	podman save --format oci-archive $(EXPORTER_IMAGE) | sudo k3s ctr images import -

deploy: secrets-check
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install $(RELEASE) $(CHART) \
		-f $(VALUES) \
		-n $(NAMESPACE) \
		--set-string secrets.serverPassword="$$VALHEIM_SERVER_PASSWORD"

status:
	kubectl -n $(NAMESPACE) get statefulset,pod,pvc,svc -l app.kubernetes.io/instance=$(RELEASE)

logs:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c gameserver

logs-exporter:
	kubectl -n $(NAMESPACE) logs -f $(RELEASE)-0 -c metrics-exporter

restart:
	kubectl -n $(NAMESPACE) rollout restart statefulset/$(RELEASE)

shell:
	kubectl -n $(NAMESPACE) exec -it $(RELEASE)-0 -c gameserver -- sh

players:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c metrics-exporter -- wget -qO- http://127.0.0.1:9101/metrics | grep lgsm_game_players

backups:
	kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- ls -la /config/backups

port-forward-metrics:
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE)-metrics 9101:9101

# Pushed to the remote Grafana (webserver VM), not a local one -- no
# kube-prometheus-stack/sidecar here. Needs a Grafana service account
# token with dashboard-write access (GRAFANA_TOKEN) and GRAFANA_URL
# (e.g. http://grafana.192.168.0.200.nip.io), and a "valheim" folder to
# already exist there.
dashboards:
	@test -n "$$GRAFANA_TOKEN" || (echo "GRAFANA_TOKEN is not set" >&2; exit 1)
	@test -n "$$GRAFANA_URL" || (echo "GRAFANA_URL is not set" >&2; exit 1)
	@for f in grafana-dashboard-process-health.json grafana-dashboard-game-stats-logs.json; do \
		python3 -c "import json; d=json.load(open('$$f')); print(json.dumps({'dashboard': d, 'folderUid': 'valheim', 'overwrite': True}))" \
		| curl -sf -X POST "$$GRAFANA_URL/api/dashboards/db" \
			-H "Authorization: Bearer $$GRAFANA_TOKEN" -H "Content-Type: application/json" -d @- ; \
		echo ; \
	done

uninstall:
	helm uninstall $(RELEASE) -n $(NAMESPACE)
