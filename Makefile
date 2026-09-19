SHELL := /bin/bash

# Local, gitignored -- put VM_HOST=user@host here so it isn't committed.
-include .env

# The k3s box has a stable LAN address; a laptop/desktop usually doesn't, so
# these only work run from your own machine (the "host"), pushing to or
# pulling from the VM over SSH -- not the other way around.
VM_HOST ?=

.PHONY: help copy-to-vm copy-to-host check-vm-host grafana-password

check-vm-host:
	@test -n "$(VM_HOST)" || { \
		echo "VM_HOST is not set -- add VM_HOST=user@host to a local .env (gitignored)," >&2; \
		echo "or pass it directly: VM_HOST=user@host make ..." >&2; exit 1; }

help:
	@echo "make copy-to-vm   FILE=<local path>  DEST=<path on the VM>   scp a file up to the VM"
	@echo "make copy-to-host FILE=<path on VM>   DEST=<local path>      scp a file down from the VM"
	@echo "                  (needs VM_HOST=user@host -- see check-vm-host)"
	@echo "make grafana-password                                       Grafana admin password (on the VM)"

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
