SHELL := /bin/bash

# The k3s box has a stable LAN address; a laptop/desktop usually doesn't, so
# these only work run from your own machine (the "host"), pushing to or
# pulling from the VM over SSH -- not the other way around.
VM_HOST ?= vhserver@192.168.0.129

.PHONY: help copy-to-vm copy-to-host

help:
	@echo "make copy-to-vm   FILE=<local path>  DEST=<path on the VM>   scp a file up to the VM"
	@echo "make copy-to-host FILE=<path on VM>   DEST=<local path>      scp a file down from the VM"
	@echo "                  (override VM_HOST=user@host if not $(VM_HOST))"

copy-to-vm:
	@test -n "$(FILE)" && test -n "$(DEST)" || { \
		echo "usage: make copy-to-vm FILE=<local path> DEST=<path on the VM>" >&2; exit 1; }
	scp -r "$(FILE)" "$(VM_HOST):$(DEST)"

copy-to-host:
	@test -n "$(FILE)" && test -n "$(DEST)" || { \
		echo "usage: make copy-to-host FILE=<path on the VM> DEST=<local path>" >&2; exit 1; }
	scp -r "$(VM_HOST):$(FILE)" "$(DEST)"
