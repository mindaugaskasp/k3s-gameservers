SHELL := /bin/bash

# Local, gitignored -- put VM_HOST=user@host here so it isn't committed.
-include .env

# The k3s box has a stable LAN address; a laptop/desktop usually doesn't, so
# these only work run from your own machine (the "host"), pushing to or
# pulling from the VM over SSH -- not the other way around.
VM_HOST ?=
# rclone remote:path for off-host backups, e.g. gdrive:k3s-gameservers-backups.
OFFSITE_BACKUP_REMOTE ?=

# Every games/<game>/ with a Makefile.
GAMES := $(patsubst games/%/Makefile,%,$(wildcard games/*/Makefile))

.PHONY: help copy-to-vm copy-to-host check-vm-host grafana-password \
	setup check-site-env k3s registry monitoring maintenance dashboards \
	offsite-backup install-offsite-backup-timer

check-vm-host:
	@test -n "$(VM_HOST)" || { \
		echo "VM_HOST is not set -- add VM_HOST=user@host to a local .env (gitignored)," >&2; \
		echo "or pass it directly: VM_HOST=user@host make ..." >&2; exit 1; }

help:
	@echo "make setup                  k3s + registry + monitoring + maintenance + dashboards (on the VM)"
	@echo "make k3s | registry | monitoring | maintenance   one install step"
	@echo "make dashboards             ship Grafana dashboards for: $(GAMES)"
	@echo "make copy-to-vm   FILE=<local path>  DEST=<path on the VM>   scp a file up to the VM"
	@echo "make copy-to-host FILE=<path on VM>   DEST=<local path>      scp a file down from the VM"
	@echo "                  (needs VM_HOST=user@host -- see check-vm-host)"
	@echo "make grafana-password                                       Grafana admin password (on the VM)"
	@echo "make offsite-backup | install-offsite-backup-timer          sync running games, rclone them off the host"

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

setup: check-site-env k3s registry monitoring maintenance dashboards
	@echo "Platform ready. Deploy a game: cd games/<game> && make push-metrics-image deploy"

check-site-env:
	@test -f monitoring/.env || { \
		echo "Missing monitoring/.env -- cp monitoring/.env.example monitoring/.env, then edit" >&2; exit 1; }

k3s:
	./install/k3s.sh

registry:
	./install/registry.sh

monitoring: check-site-env
	./install/monitoring.sh

maintenance:
	KUBECONFIG=$${KUBECONFIG:-$$HOME/.kube/config} kubectl apply -k maintenance

dashboards:
	@for g in $(GAMES); do $(MAKE) --no-print-directory -C games/$$g dashboards || exit 1; done

offsite-backup:
	@command -v rclone >/dev/null || { echo "rclone not installed, see docs/offsite-backups.md" >&2; exit 1; }
	OFFSITE_BACKUP_REMOTE=$(OFFSITE_BACKUP_REMOTE) ./offsite-backup/offsite-backup.sh

install-offsite-backup-timer:
	@test -d /run/systemd/system || { echo "systemd not found; run this on the k3s host" >&2; exit 1; }
	@sed -e "s|__REPO__|$(CURDIR)|g" -e "s|__USER__|$$(id -un)|g" -e "s|__HOME__|$$HOME|g" \
		offsite-backup/systemd/offsite-backup.service | sudo tee /etc/systemd/system/offsite-backup.service >/dev/null
	@sudo cp offsite-backup/systemd/offsite-backup.timer /etc/systemd/system/offsite-backup.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now offsite-backup.timer
	systemctl list-timers offsite-backup.timer --no-pager
