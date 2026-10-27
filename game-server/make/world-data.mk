# Copying a game's world and backups off the pod, and restoring one. Included by game.mk,
# which sets the paths and options these targets read.

# Read-only pulls from the running pod; restore-backup is the only path that writes back.
## Copy the world, config and backups from the pod into data/ and data-backups/
sync: sync-data sync-backups

# Both mirror the pod, so a world snapshot the server pruned stops being synced and
# uploaded here as well.
sync-data:
	@$(GAME_SERVER_DIR)/sync-folder-from-pod.sh $(NAMESPACE) $(RELEASE)-0 \
		$(GAME_DATA_PATH) $(DATA_DIR) $(SYNC_DATA_EXCLUDES)

sync-backups:
ifeq ($(BACKUP_SYNC_RETENTION_DAYS),)
	@REQUIRED_FILE_PATTERN='$(BACKUP_FILE_PATTERN)' $(GAME_SERVER_DIR)/sync-folder-from-pod.sh \
		$(NAMESPACE) $(RELEASE)-0 $(GAME_BACKUP_PATH) $(BACKUP_DIR)
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

## Download the newest off-host archive and verify it opens and holds the world
##   OFFSITE_BACKUP_REMOTE=remote:path   rclone source, or set it in the root .env
verify-offsite-backup:
	@FILE_PATTERN='$(BACKUP_FILE_PATTERN)' LIST_COMMAND='$(BACKUP_ARCHIVE_LIST_COMMAND)' \
		REQUIRED_ENTRY='$(RESTORE_REQUIRED_ARCHIVE_ENTRY)' $(GAME_SERVER_DIR)/verify-offsite-copy.sh \
		"$(OFFSITE_REMOTE)" $(GAME_FOLDER) $(GAME_FOLDER)

## Download the newest off-host world bundle and verify it opens
##   OFFSITE_BACKUP_REMOTE=remote:path   rclone source, or set it in the root .env
verify-offsite-data-bundle:
	@$(GAME_SERVER_DIR)/verify-offsite-copy.sh "$(OFFSITE_REMOTE)" $(GAME_FOLDER)/data-bundles $(GAME_FOLDER)

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
##   Pick from the fzf list: Tab moves, Enter restores; FORCE=1 ignores players online.
##   RESTORE_WARNING='--force-with-message="text" --time=10m' warns them; Ctrl + C cancels.
restore-backup:
	@selected_backup=$$($(GAME_SERVER_DIR)/choose-backup.sh $(BACKUP_DIR) '$(BACKUP_FILE_PATTERN)') || exit 1; \
	$(MAKE) _restore-run BACKUP="$$selected_backup" RESTORE_WARNING='$(RESTORE_WARNING)'

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

# The game's restore-backup.sh puts the backup over the volume, inside the helper pod.
_restore-run:
	@test -n "$(BACKUP)" || { echo "usage: make _restore-run BACKUP=$(BACKUP_DIR)/<file>" >&2; exit 1; }
	@test -f "$(BACKUP)" || { echo "no such file: $(BACKUP)" >&2; exit 1; }
	@[ -z "$(RESTORE_REQUIRED_ARCHIVE_ENTRY)" ] || $(BACKUP_ARCHIVE_LIST_COMMAND) "$(BACKUP)" | grep -- "$(RESTORE_REQUIRED_ARCHIVE_ENTRY)" >/dev/null \
		|| { echo "$(BACKUP) has no $(RESTORE_REQUIRED_ARCHIVE_ENTRY) in it -- refusing" >&2; exit 1; }
	@echo "This REPLACES the live world of '$(RELEASE)' with $(BACKUP)."
	@read -r -p "Type $(RELEASE) to confirm: " a; [ "$$a" = "$(RELEASE)" ] || { echo "aborted" >&2; exit 1; }
	@if [ -n "$(if $(strip $(RESTORE_WARNING)),warn,)" ]; then \
		test -n "$(BROADCAST_COMMAND)" || { echo "$(RELEASE) cannot message players, so it has no RESTORE_WARNING" >&2; exit 1; }; \
		BROADCAST_COMMAND="$(BROADCAST_COMMAND)" $(GAME_SERVER_DIR)/warn-players-and-wait.sh $(RESTORE_WARNING); \
	else \
		$(MAKE) --no-print-directory check-no-players; \
	fi
	@$(MAKE) --no-print-directory start-volume-helper
	kubectl -n $(NAMESPACE) cp "$(BACKUP)" $(RELEASE)-restore-helper:/tmp/restore-backup
	kubectl -n $(NAMESPACE) exec -i $(RELEASE)-restore-helper -- sh < restore-backup.sh
	@$(MAKE) --no-print-directory stop-volume-helper
	kubectl -n $(NAMESPACE) scale statefulset/$(RELEASE) --replicas=1
	@echo "Restored $(BACKUP). Watch it come up with: make logs"
