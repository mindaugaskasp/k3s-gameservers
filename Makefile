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

include make/help.mk

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

## Copy a file or folder from your machine to the VM over scp
##   FILE=PATH           the file or folder on your machine
##   DEST=PATH           where to put it on the VM
##   VM_HOST=user@host   the VM to reach over SSH, or set it in .env
##   e.g. make copy-to-vm FILE=backup.zip DEST=k3s-gameservers/
copy-to-vm: check-vm-host
	@test -n "$(FILE)" && test -n "$(DEST)" || { \
		echo "usage: make copy-to-vm FILE=<local path> DEST=<path on the VM>" >&2; exit 1; }
	scp -r "$(FILE)" "$(VM_HOST):$(DEST)"

## Copy a file or folder from the VM to your machine over scp
##   FILE=PATH           the file or folder on the VM
##   DEST=PATH           where to put it on your machine
##   VM_HOST=user@host   the VM to reach over SSH, or set it in .env
##   e.g. make copy-to-host FILE=k3s-gameservers/README.md DEST=.
copy-to-host: check-vm-host
	@test -n "$(FILE)" && test -n "$(DEST)" || { \
		echo "usage: make copy-to-host FILE=<path on the VM> DEST=<local path>" >&2; exit 1; }
	scp -r "$(VM_HOST):$(FILE)" "$(DEST)"

## Print Grafana's admin password (on the VM)
grafana-password:
	@KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config} kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.password}' | base64 -d; echo

## Install the whole platform on the VM
##   Runs, in order: k3s, crowdsec, firewall, registry, monitoring, maintenance, dashboards
##   Needs monitoring/.env: copy monitoring/.env.example, then edit.
setup: check-site-env k3s crowdsec firewall registry monitoring maintenance dashboards
	@echo "Platform ready. Deploy a game: cd games/<game> && make push-metrics-image deploy"

check-site-env:
	@test -f monitoring/.env || { \
		echo "Missing monitoring/.env -- cp monitoring/.env.example monitoring/.env, then edit" >&2; exit 1; }

## Install k3s with this repo's Traefik settings (on the VM)
k3s:
	./install/k3s.sh

## Install CrowdSec and its Traefik bouncer (on the VM)
##   Run it before Traefik loads install/k3s/traefik-config.yaml, which needs the bouncer.
crowdsec:
	./install/crowdsec.sh

## Set up ufw: SSH, the LAN and pods in, game ports and 80/443 routed (on the VM)
##   Needs monitoring/.env.
firewall: check-site-env
	./install/firewall.sh

## Install the in-cluster image registry (on the VM)
registry:
	./install/registry.sh

## Install or update Prometheus, Loki, Alloy and Grafana (on the VM)
##   Needs monitoring/.env, with ALERTS_DISCORD_WEBHOOK_URL set.
monitoring: check-site-env
	./install/monitoring.sh

## Install the CronJob that deletes pods stuck after a reboot (on the VM)
maintenance:
	KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config} kubectl apply -k maintenance

## Ship every game's Grafana dashboards (runs make dashboards in each games/<game>)
dashboards:
	@for g in $(GAMES); do $(MAKE) --no-print-directory -C games/$$g dashboards || exit 1; done

## Ban an IP in CrowdSec, so Traefik answers it with 403 (on the VM)
##   <ip>                the address to ban
##   [hours]             how long the ban lasts, 24 by default
##   e.g. make ban-ip 203.0.113.7 48
ban-ip:
	@test -n "$(BAN_IP)" && [[ "$(BAN_HOURS)" =~ ^[1-9][0-9]*$$ ]] || { \
		echo "usage: make ban-ip <ip> [hours]" >&2; exit 1; }
	KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config} kubectl -n crowdsec exec deploy/crowdsec-lapi -- \
		cscli decisions add --ip "$(BAN_IP)" --duration "$(BAN_HOURS)h" --reason "manual ban"

## Lift a CrowdSec ban (on the VM)
##   <ip>                the banned address
##   e.g. make unban-ip 203.0.113.7
unban-ip:
	@test -n "$(BAN_IP)" || { echo "usage: make unban-ip <ip>" >&2; exit 1; }
	KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config} kubectl -n crowdsec exec deploy/crowdsec-lapi -- \
		cscli decisions delete --ip "$(BAN_IP)"

## Sync the running games and upload them off the host now
##   OFFSITE_BACKUP_REMOTE=remote:path   rclone destination, or set it in .env
##   LOKI_URL=URL                        where to report the result for alerts, or set it in .env
offsite-backup:
	@command -v rclone >/dev/null || { echo "rclone not installed, see docs/offsite-backups.md" >&2; exit 1; }
	OFFSITE_BACKUP_REMOTE=$(OFFSITE_BACKUP_REMOTE) LOKI_URL=$(LOKI_URL) ./offsite-backup/offsite-backup.sh

## Install rclone, log in to Google Drive, take a first backup and start a 6-hourly timer
##   Safe to re-run. Over SSH, connect with -L 53682:localhost:53682 for the Drive login.
setup-offsite-backup:
	./install/offsite-backup.sh
