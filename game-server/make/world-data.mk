# Copying a game's world and backups off the pod, and restoring one. Included by game.mk,
# which sets the paths and options these targets read.

# Read-only pulls from the running pod; restore-backup is the only path that writes back.
## Copy the world, config and backups from the pod into data/ and data-backups/
sync: sync-data sync-backups

sync-data:
	@mkdir -p $(DATA_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C $(GAME_DATA_PATH) $(foreach folder,$(SYNC_DATA_EXCLUDES),--exclude=./$(folder)) . \
		| tar xf - -C $(DATA_DIR)
	@echo "Synced $(GAME_DATA_PATH) -> $(DATA_DIR)/"

# A mirror is swapped in only once complete and only if the server still has backups,
# so a failed pull keeps the old copy.
sync-backups:
ifeq ($(BACKUP_SYNC_RETENTION_DAYS),)
	@rm -rf $(BACKUP_DIR).new && mkdir -p $(BACKUP_DIR).new
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C $(GAME_BACKUP_PATH) . | tar xf - -C $(BACKUP_DIR).new
	@ls $(BACKUP_DIR).new/*.zip >/dev/null 2>&1 || { \
		echo "server has no backups; keeping $(BACKUP_DIR)/ unchanged" >&2; rm -rf $(BACKUP_DIR).new; exit 1; }
	@rm -rf $(BACKUP_DIR).old; if [ -d $(BACKUP_DIR) ]; then mv $(BACKUP_DIR) $(BACKUP_DIR).old; fi
	@mv $(BACKUP_DIR).new $(BACKUP_DIR) && rm -rf $(BACKUP_DIR).old
	@echo "Synced $(GAME_BACKUP_PATH) -> $(BACKUP_DIR)/"
else
	@mkdir -p $(BACKUP_DIR)
	@kubectl -n $(NAMESPACE) exec $(RELEASE)-0 -c gameserver -- \
		tar cf - -C $(GAME_BACKUP_PATH) . | tar xf - -C $(BACKUP_DIR)
	@find $(BACKUP_DIR) -type f -mtime +$(BACKUP_SYNC_RETENTION_DAYS) -print -delete
	@echo "Synced $(GAME_BACKUP_PATH) -> $(BACKUP_DIR)/ (keeping $(BACKUP_SYNC_RETENTION_DAYS) days)"
endif

VM_REPO_DIR := k3s-gameservers
## Copy every backup synced on the VM to this machine's data-backups/
##   Run it from your own machine, not the VM.
##   VM_HOST=user@host   the VM to reach over SSH, or set it in the root .env
download-backups:
	@mkdir -p $(BACKUP_DIR)
	$(MAKE) -C $(REPO_ROOT) copy-to-host \
		FILE=$(VM_REPO_DIR)/games/$(GAME_FOLDER)/$(BACKUP_DIR)/. DEST=$(BACKUP_DIR)

## Run make sync every hour with a systemd timer (on the k3s host; asks for sudo)
install-sync-timer:
	@test -d /run/systemd/system || { echo "systemd not found; run this on the k3s host" >&2; exit 1; }
	@sed -e "s|__REPO__|$(REPO_ROOT)|g" -e "s|__USER__|$$(id -un)|g" -e "s|__HOME__|$$HOME|g" \
		$(GAME_SERVER_DIR)/systemd/game-data-sync@.service | sudo tee /etc/systemd/system/game-data-sync@.service >/dev/null
	@sudo cp $(GAME_SERVER_DIR)/systemd/game-data-sync@.timer /etc/systemd/system/game-data-sync@.timer
	sudo systemctl daemon-reload
	sudo systemctl enable --now game-data-sync@$(GAME_FOLDER).timer
	systemctl list-timers game-data-sync@$(GAME_FOLDER).timer --no-pager

## Replace the live world with a backup from data-backups/, then start the server
##   Lists the backups, asks for a number, then asks you to type the game name to confirm.
##   Run make sync or make download-backups first.
restore-backup:
	@mapfile -t backups < <(find $(BACKUP_DIR) -name '*.zip' -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-); \
	test $${#backups[@]} -gt 0 || { echo "no backups in $(BACKUP_DIR)/ -- run 'make sync' or 'make download-backups' first" >&2; exit 1; }; \
	echo "Available backups (newest first):"; \
	for i in "$${!backups[@]}"; do \
		printf "  %2d) %-34s %s  %s\n" "$$((i + 1))" "$${backups[$$i]#$(BACKUP_DIR)/}" \
			"$$(date -r "$${backups[$$i]}" '+%Y-%m-%d %H:%M')" "$$(du -h "$${backups[$$i]}" | cut -f1)"; \
	done; \
	read -r -p "Select a backup to restore (number): " n; \
	idx=$$((n - 1)); \
	[ "$$idx" -ge 0 ] 2>/dev/null && [ "$$idx" -lt $${#backups[@]} ] || { echo "invalid selection" >&2; exit 1; }; \
	$(MAKE) _restore-run BACKUP="$${backups[$$idx]}"

RESTORE_HELPER_POD = sed 's/__RELEASE__/$(RELEASE)/g' $(GAME_SERVER_DIR)/restore-helper-pod.yaml

## Stop the game and start a helper pod with its volume at /data, to edit files by hand
##   make stop-volume-helper removes it; then make scale-up starts the game.
start-volume-helper:
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=0
	kubectl -n $(NAMESPACE) wait --for=delete pod/$(RELEASE)-0 --timeout=300s
	$(RESTORE_HELPER_POD) | kubectl -n $(NAMESPACE) apply -f -
	kubectl -n $(NAMESPACE) wait --for=condition=Ready pod/$(RELEASE)-restore-helper --timeout=180s

## Remove the helper pod start-volume-helper started
stop-volume-helper:
	$(RESTORE_HELPER_POD) | kubectl -n $(NAMESPACE) delete --wait -f -

# The game's restore-backup.sh unpacks the zip over the volume, inside the helper pod.
_restore-run:
	@test -n "$(BACKUP)" || { echo "usage: make _restore-run BACKUP=$(BACKUP_DIR)/<file>.zip" >&2; exit 1; }
	@test -f "$(BACKUP)" || { echo "no such file: $(BACKUP)" >&2; exit 1; }
	@unzip -l "$(BACKUP)" | grep -q -- "$(RESTORE_REQUIRED_ZIP_ENTRY)" \
		|| { echo "$(BACKUP) has no $(RESTORE_REQUIRED_ZIP_ENTRY) in it -- refusing" >&2; exit 1; }
	@echo "This REPLACES the live world of '$(RELEASE)' with $(BACKUP)."
	@read -r -p "Type $(RELEASE) to confirm: " a; [ "$$a" = "$(RELEASE)" ] || { echo "aborted" >&2; exit 1; }
	@$(MAKE) --no-print-directory start-volume-helper
	kubectl -n $(NAMESPACE) cp "$(BACKUP)" $(RELEASE)-restore-helper:/tmp/restore.zip
	kubectl -n $(NAMESPACE) exec -i $(RELEASE)-restore-helper -- sh < restore-backup.sh
	@$(MAKE) --no-print-directory stop-volume-helper
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=1
	@echo "Restored $(BACKUP). Watch it come up with: make logs"
