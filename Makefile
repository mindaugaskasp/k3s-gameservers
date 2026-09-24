SHELL := /bin/bash

# Local, gitignored -- put VM_HOST=user@host here so it isn't committed.
-include .env

# The k3s box has a stable LAN address; a laptop/desktop usually doesn't, so
# these only work run from your own machine (the "host"), pushing to or
# pulling from the VM over SSH -- not the other way around.
VM_HOST ?=
# rclone remote:path for off-host backups, e.g. gdrive:k3s-gameservers-backups.
OFFSITE_BACKUP_REMOTE ?=
# Loki's LAN push base URL; offsite-backup reports each run's result there for alerting.
LOKI_URL ?=

# Every games/<game>/ with a Makefile.
GAMES := $(patsubst games/%/Makefile,%,$(wildcard games/*/Makefile))

# `make ban-ip <ip> [hours]` / `make unban-ip <ip>`: read the arguments from the goal
# list and make each one a no-op target, so make doesn't try to build it.
ifneq (,$(filter $(firstword $(MAKECMDGOALS)),ban-ip unban-ip))
BAN_IP := $(word 2,$(MAKECMDGOALS))
BAN_HOURS := $(or $(word 3,$(MAKECMDGOALS)),24)
$(foreach argument,$(wordlist 2,3,$(MAKECMDGOALS)),$(eval $(argument):;@:))
endif

.PHONY: help copy-to-vm copy-to-host check-vm-host grafana-password \
	setup check-site-env k3s crowdsec firewall registry monitoring maintenance dashboards ban-ip unban-ip \
	offsite-backup setup-offsite-backup

check-vm-host:
	@test -n "$(VM_HOST)" || { \
		echo "VM_HOST is not set -- add VM_HOST=user@host to a local .env (gitignored)," >&2; \
		echo "or pass it directly: VM_HOST=user@host make ..." >&2; exit 1; }

help:
	@echo "make setup                  k3s + crowdsec + firewall + registry + monitoring + maintenance + dashboards (on the VM)"
	@echo "make k3s | crowdsec | firewall | registry | monitoring | maintenance   one install step"
	@echo "make dashboards             ship Grafana dashboards for: $(GAMES)"
	@echo "make copy-to-vm   FILE=<local path>  DEST=<path on the VM>   scp a file up to the VM"
	@echo "make copy-to-host FILE=<path on VM>   DEST=<local path>      scp a file down from the VM"
	@echo "                  (needs VM_HOST=user@host -- see check-vm-host)"
	@echo "make ban-ip <ip> [hours]                                ban an IP in CrowdSec, 24 hours by default (on the VM)"
	@echo "make unban-ip <ip>                                      lift a CrowdSec ban (on the VM)"
	@echo "make grafana-password                                       Grafana admin password (on the VM)"
	@echo "make setup-offsite-backup    rclone + Drive login + first backup + 6-hourly timer (re-runnable;"
	@echo "                             over SSH, connect with -L 53682:localhost:53682 for the login)"
	@echo "make offsite-backup          sync running games and rclone them off the host now"

copy-to-vm: check-vm-host
	@test -n "$(FILE)" && test -n "$(DEST)" || { \
		echo "usage: make copy-to-vm FILE=<local path> DEST=<path on the VM>" >&2; exit 1; }
	scp -r "$(FILE)" "$(VM_HOST):$(DEST)"

copy-to-host: check-vm-host
	@test -n "$(FILE)" && test -n "$(DEST)" || { \
		echo "usage: make copy-to-host FILE=<path on the VM> DEST=<local path>" >&2; exit 1; }
	scp -r "$(VM_HOST):$(FILE)" "$(DEST)"

grafana-password:
	@KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config} kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.password}' | base64 -d; echo

setup: check-site-env k3s crowdsec firewall registry monitoring maintenance dashboards
	@echo "Platform ready. Deploy a game: cd games/<game> && make push-metrics-image deploy"

check-site-env:
	@test -f monitoring/.env || { \
		echo "Missing monitoring/.env -- cp monitoring/.env.example monitoring/.env, then edit" >&2; exit 1; }

k3s:
	./install/k3s.sh

crowdsec:
	./install/crowdsec.sh

firewall: check-site-env
	./install/firewall.sh

registry:
	./install/registry.sh

monitoring: check-site-env
	./install/monitoring.sh

maintenance:
	KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config} kubectl apply -k maintenance

dashboards:
	@for g in $(GAMES); do $(MAKE) --no-print-directory -C games/$$g dashboards || exit 1; done

ban-ip:
	@test -n "$(BAN_IP)" && [[ "$(BAN_HOURS)" =~ ^[1-9][0-9]*$$ ]] || { \
		echo "usage: make ban-ip <ip> [hours]" >&2; exit 1; }
	KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config} kubectl -n crowdsec exec deploy/crowdsec-lapi -- \
		cscli decisions add --ip "$(BAN_IP)" --duration "$(BAN_HOURS)h" --reason "manual ban"

unban-ip:
	@test -n "$(BAN_IP)" || { echo "usage: make unban-ip <ip>" >&2; exit 1; }
	KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config} kubectl -n crowdsec exec deploy/crowdsec-lapi -- \
		cscli decisions delete --ip "$(BAN_IP)"

offsite-backup:
	@command -v rclone >/dev/null || { echo "rclone not installed, see docs/offsite-backups.md" >&2; exit 1; }
	OFFSITE_BACKUP_REMOTE=$(OFFSITE_BACKUP_REMOTE) LOKI_URL=$(LOKI_URL) ./offsite-backup/offsite-backup.sh

setup-offsite-backup:
	./install/offsite-backup.sh
