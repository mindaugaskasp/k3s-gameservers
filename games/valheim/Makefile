# Common k3s/helm operations for the Valheim instance. Run from this
# directory (games/valheim/) or via `make -C games/valheim <target>`.
#
# Not LGSM: this uses charts/valheim-server (community valheim-server-docker
# image), not charts/linuxgsm-game -- LGSM's Valheim install crashed
# reproducibly in this cluster's containers, see docs/architecture.md.
# Update/restart/backups are handled inside the container itself via
# cron-format env vars in values.yaml, not k8s CronJobs.
#
# Secrets are never read from this Makefile or from values.yaml -- export
# it in your shell first:
#   export VALHEIM_SERVER_PASSWORD=...

SHELL := /bin/bash
CHART := ../../charts/valheim-server
RELEASE := valheim
NAMESPACE := games
VALUES := values.yaml
EXPORTER_DIR := ../../monitoring/exporter
EXPORTER_IMAGE := k3s-linuxgsm/lgsm-exporter:latest

.PHONY: help lint template deploy status logs logs-exporter \
	restart shell port-forward-metrics port-forward-game \
	dashboard secrets-check uninstall build-exporter import-exporter \
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
	@echo "make dashboard             (re)apply the Grafana dashboard ConfigMap"
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

dashboard:
	kubectl -n $(NAMESPACE) create configmap $(RELEASE)-grafana-dashboard \
		--from-file=dashboard.json=grafana-dashboard.json \
		--dry-run=client -o yaml \
		| kubectl label -f - --local -o yaml grafana_dashboard="1" \
		| kubectl apply -f -

uninstall:
	helm uninstall $(RELEASE) -n $(NAMESPACE)
